// The provider is pure state, so it needs foundation (ChangeNotifier,
// kIsWeb, visibleForTesting) and services (HapticFeedback) only.
// `material.dart` re-exports just part of foundation, which is why kIsWeb
// needs this explicit import; material itself is not used here.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/inventory_item.dart';
import '../models/transaction.dart';
import '../models/operator_user.dart';
import '../data/initial_data.dart';
import '../services/supabase_service.dart';
import '../services/auth_service.dart';

class InventoryProvider extends ChangeNotifier {
  List<InventoryItem> _items = List.from(initialInventoryItems);
  List<InventoryTransaction> _transactions = List.from(initialTransactions);
  List<OperatorUser> _operators = List.from(initialOperators);
  late OperatorUser _currentOperator;

  String _searchQuery = '';
  InventoryCategory? _selectedCategory;
  bool _filterLowStockOnly = false;
  bool _isSyncing = false;
  String? _syncStatusMessage;
  String? _lastError;

  /// Whether the most recent stock movement actually reached the database.
  ///
  /// False means the change exists only in memory. The UI has to say so,
  /// because a local-only save is otherwise indistinguishable from a synced
  /// one - which is exactly what made the web build look healthy while nothing
  /// was ever persisted.
  bool _lastSaveReachedServer = false;

  final SupabaseService _supabase = SupabaseService();
  final AuthService _auth = AuthService();

  InventoryProvider() {
    _currentOperator = _operators.first;
    _initSupabase();
  }

  /// Adopt the operator who just signed in and pull the roster from the
  /// database, so the roster reflects real accounts rather than the
  /// hardcoded fallback list.
  Future<void> bindToSession() async {
    final signedIn = _auth.currentOperator;
    if (signedIn != null) {
      _currentOperator = signedIn;

      final roster = await _auth.fetchOperators();
      if (roster.isNotEmpty) {
        _operators = roster;
        // Keep the displayed operator in step with the freshly loaded roster.
        for (final op in roster) {
          if (op.id == _currentOperator.id) {
            _currentOperator = op;
            break;
          }
        }
      }
      notifyListeners();
    }

    await refreshFromSupabase();

    // Realtime must be (re)subscribed *after* sign-in. The channels are
    // authenticated with the operator JWT and every table has RLS enabled, so
    // a subscription opened before sign-in silently receives nothing.
    _subscribeToRealtime();

    _startHeartbeat();
  }

  /// Open the realtime channels, replacing any previous pair.
  void _subscribeToRealtime() {
    if (!_supabase.isConfigured) return;
    _supabase.subscribeToRealtimeUpdates(
      onItemUpdated: (payload) {
        final updated = InventoryItem.fromJson(payload);
        final index = _items.indexWhere((i) => i.id == updated.id);
        if (index != -1) {
          _items[index] = updated;
        } else {
          _items.insert(0, updated);
        }
        notifyListeners();
      },
      onTransactionInserted: (payload) {
        final txn = InventoryTransaction.fromJson(payload);
        if (!_transactions.any((t) => t.id == txn.id)) {
          _transactions.insert(0, txn);
          notifyListeners();
        }
      },
    );
  }

  /// Keep the server-side session row fresh so idle sessions can be reaped.
  void _startHeartbeat() {
    Future.delayed(const Duration(minutes: 5), () {
      if (_auth.isAuthenticated) {
        _auth.heartbeat();
        _startHeartbeat();
      }
    });
  }


  // Getters
  List<InventoryItem> get items => _items;
  List<InventoryTransaction> get transactions => _transactions;
  List<OperatorUser> get operators => _operators;
  OperatorUser get currentOperator => _currentOperator;
  String get searchQuery => _searchQuery;
  InventoryCategory? get selectedCategory => _selectedCategory;
  bool get filterLowStockOnly => _filterLowStockOnly;
  bool get isSyncing => _isSyncing;
  String? get syncStatusMessage => _syncStatusMessage;
  String? get lastError => _lastError;
  bool get lastSaveReachedServer => _lastSaveReachedServer;
  bool get isSupabaseConnected => _supabase.isConfigured;

  /// True only when a database AND a signed-in operator are both present.
  /// Stock writes are refused unless this is true, so an unauthenticated
  /// device can never silently alter shared company data.
  bool get canWriteToServer => _supabase.isReady && _auth.isAuthenticated;


  // Filtered items
  List<InventoryItem> get filteredItems {
    return _items.where((item) {
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      if (_filterLowStockOnly && !item.isLowStock && !item.isOutOfStock) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = item.name.toLowerCase().contains(q);
        final matchesSku = item.sku.toLowerCase().contains(q);
        final matchesBarcode = item.barcode?.toLowerCase().contains(q) ?? false;
        final matchesLocation = item.location?.toLowerCase().contains(q) ?? false;
        if (!matchesName && !matchesSku && !matchesBarcode && !matchesLocation) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  // Statistics
  int get totalStockUnits => _items.fold(0, (acc, item) => acc + item.leftCount);
  int get totalItemsSold => _items.fold(0, (acc, item) => acc + item.totalSold);
  int get lowStockCount => _items.where((item) => item.isLowStock || item.isOutOfStock).length;
  double get totalInventoryValuation =>
      _items.fold(0.0, (acc, item) => acc + (item.leftCount * item.unitCostPrice));
  double get totalSalesRevenue => _transactions
      .where((t) => t.type == TransactionType.stockSold)
      .fold(0.0, (acc, t) => acc + (t.totalAmount ?? 0.0));

  Future<void> _initSupabase() async {
    await _supabase.ensureInitialized();
    if (_supabase.isConfigured) {
      await refreshFromSupabase();
      // NOTE: realtime channels are opened later, in bindToSession(), once a
      // session binding exists - RLS blocks every event sent to an
      // unauthenticated channel, so subscribing here would deliver nothing.
    }
  }

  Future<void> refreshFromSupabase() async {
    if (!_supabase.isConfigured) return;
    _isSyncing = true;
    notifyListeners();

    try {
      final remoteItems = await _supabase.fetchInventory();
      final remoteTxns = await _supabase.fetchTransactions();
      if (remoteItems.isNotEmpty) {
        _items = remoteItems;
      }
      if (remoteTxns.isNotEmpty) {
        _transactions = remoteTxns;
      }
      _syncStatusMessage = 'Synced in real-time';
    } catch (e) {
      _syncStatusMessage = 'Sync error: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedCategory(InventoryCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleLowStockFilter() {
    _filterLowStockOnly = !_filterLowStockOnly;
    notifyListeners();
  }

  Future<void> applyLocalStockMovement({
    required String itemId,
    required String type,
    required int quantity,
    double? unitPrice,
    String? client,
    String? notes,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    // A physical audit to zero is a legitimate count - only deltas must be
    // positive. The old `quantity <= 0` guard silently dropped "audit to 0",
    // which is exactly an "add in / sold out doesn't reflect" report.
    if (index == -1) return;
    if (quantity <= 0 && type != 'correction') return;

    final item = _items[index];
    final prevCount = item.leftCount;

    int newLeftCount = prevCount;
    int totalIn = item.totalIn;
    int totalSold = item.totalSold;
    int txnQuantity = quantity;
    double txnTotalAmount = 0;
    TransactionType txnType;
    String txnNotes = notes ?? '';
    String? txnClient = client;

    switch (type) {
      case 'in':
        newLeftCount = prevCount + quantity;
        totalIn = item.totalIn + quantity;
        txnType = TransactionType.stockIn;
        txnTotalAmount = (unitPrice ?? item.unitCostPrice) * quantity;
        break;
      case 'sold':
        final safeQuantity = quantity > prevCount ? prevCount : quantity;
        newLeftCount = prevCount - safeQuantity;
        totalSold = item.totalSold + safeQuantity;
        txnQuantity = safeQuantity;
        txnType = TransactionType.stockSold;
        txnTotalAmount = (unitPrice ?? item.unitSellingPrice) * safeQuantity;
        break;
      case 'correction':
        newLeftCount = quantity;
        txnType = TransactionType.countCorrection;
        txnQuantity = (quantity - prevCount).abs();
        txnNotes = notes ??
            'Physical count adjustment (${quantity >= prevCount ? "+${quantity - prevCount}" : "${quantity - prevCount}"})';
        txnClient = null;
        break;
      default:
        return;
    }

    final updatedItem = item.copyWith(
      leftCount: newLeftCount,
      totalIn: totalIn,
      totalSold: totalSold,
      lastUpdated: DateTime.now(),
      lastUpdatedBy: _currentOperator.name,
    );

    _items[index] = updatedItem;

    final txn = InventoryTransaction(
      id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
      itemId: item.id,
      itemName: item.name,
      itemSku: item.sku,
      type: txnType,
      quantity: txnQuantity,
      previousLeftCount: prevCount,
      newLeftCount: newLeftCount,
      unitPrice: txnType == TransactionType.countCorrection ? 0 : (unitPrice ?? (txnType == TransactionType.stockIn ? item.unitCostPrice : item.unitSellingPrice)),
      totalAmount: txnType == TransactionType.countCorrection ? 0 : txnTotalAmount,
      clientOrSupplier: txnClient,
      notes: txnNotes.isEmpty ? null : txnNotes,
      operatorName: _currentOperator.name,
      deviceId: _currentOperator.deviceLabel,
      timestamp: DateTime.now(),
    );

    _transactions.insert(0, txn);
    // Every local-only save funnels through here, so this is the single place
    // that records "the database has not seen this". Callers read it via
    // [lastSaveReachedServer] and warn the operator accordingly.
    _lastSaveReachedServer = false;
    _syncStatusMessage = 'Saved locally. Sync will retry when connected.';
    HapticFeedback.lightImpact();
    notifyListeners();

    if (_supabase.isConfigured) {
      // Best-effort push of the local snapshot. Awaited (not fire-and-forget)
      // so a rejected write is reported via _lastError instead of vanishing
      // into an unobserved future while the next refresh wipes the change.
      try {
        await _supabase.upsertItem(updatedItem);
        await _supabase.logTransaction(txn);
      } catch (e) {
        debugPrint('InventoryProvider.applyLocalStockMovement push failed: $e');
        _lastError = _friendlyError(e);
        notifyListeners();
      }
    }
  }

  Future<void> recordStockIn({
    required String itemId,
    required int quantity,
    double? unitPrice,
    String? supplier,
    String? notes,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1 || quantity <= 0) return;

    if (canWriteToServer) {
      // Server-side: the database performs the arithmetic under a row lock
      // and writes the item + audit rows atomically, stamped with the
      // signed-in operator. Local state is then refreshed from the result,
      // so a concurrent sale on another device is never overwritten.
      try {
        final result = await _supabase.applyStockMovement(
          itemId: itemId,
          type: 'in',
          quantity: quantity,
          unitPrice: unitPrice,
          client: supplier,
          notes: notes,
        );
        _lastError = null;
        _lastSaveReachedServer = true;
        // Paint the committed count immediately from the RPC result, then pull
        // the audit row. No refresh needed for the screen to update.
        _applyMovementResult(result, itemId);
        notifyListeners();
        await _reloadItemAndTxns(itemId);
        HapticFeedback.mediumImpact();
        return;
      } catch (e) {
        if (_shouldFallbackLocally(e)) {
          await applyLocalStockMovement(
            itemId: itemId,
            type: 'in',
            quantity: quantity,
            unitPrice: unitPrice,
            client: supplier,
            notes: notes,
          );
          return;
        }
        _lastError = _friendlyError(e);
        notifyListeners();
        return;
      }
    }

    await applyLocalStockMovement(
      itemId: itemId,
      type: 'in',
      quantity: quantity,
      unitPrice: unitPrice,
      client: supplier,
      notes: notes,
    );
  }

  Future<void> recordStockSold({
    required String itemId,
    required int quantity,
    double? unitPrice,
    String? client,
    String? notes,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1 || quantity <= 0) return;

    if (canWriteToServer) {
      // The server refuses the sale if another device has already sold
      // past the remaining stock, which is the whole point of doing the
      // arithmetic there rather than on the handset.
      try {
        final result = await _supabase.applyStockMovement(
          itemId: itemId,
          type: 'sold',
          quantity: quantity,
          unitPrice: unitPrice,
          client: client,
          notes: notes,
        );
        _lastError = null;
        _lastSaveReachedServer = true;
        // Apply the committed count straight away so "Record Sale" updates the
        // left count on screen immediately - no refresh required.
        _applyMovementResult(result, itemId);
        notifyListeners();
        await _reloadItemAndTxns(itemId);
        HapticFeedback.lightImpact();
        return;
      } catch (e) {
        if (_shouldFallbackLocally(e)) {
          await applyLocalStockMovement(
            itemId: itemId,
            type: 'sold',
            quantity: quantity,
            unitPrice: unitPrice,
            client: client,
            notes: notes,
          );
          return;
        }
        _lastError = _friendlyError(e);
        notifyListeners();
        return;
      }
    }

    await applyLocalStockMovement(
      itemId: itemId,
      type: 'sold',
      quantity: quantity,
      unitPrice: unitPrice,
      client: client,
      notes: notes,
    );
  }

  Future<void> recordCountAudit({
    required String itemId,
    required int physicalCount,
    String? reason,
  }) async {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return;

    if (canWriteToServer) {
      // `quantity` here is the PHYSICAL COUNT, not a delta.
      try {
        final result = await _supabase.applyStockMovement(
          itemId: itemId,
          type: 'correction',
          quantity: physicalCount,
          notes: reason,
        );
        _lastError = null;
        _lastSaveReachedServer = true;
        _applyMovementResult(result, itemId);
        notifyListeners();
        await _reloadItemAndTxns(itemId);
        HapticFeedback.heavyImpact();
        return;
      } catch (e) {
        if (_shouldFallbackLocally(e)) {
          await applyLocalStockMovement(
            itemId: itemId,
            type: 'correction',
            quantity: physicalCount,
            notes: reason,
          );
          return;
        }
        _lastError = _friendlyError(e);
        notifyListeners();
        return;
      }
    }

    await applyLocalStockMovement(
      itemId: itemId,
      type: 'correction',
      quantity: physicalCount,
      notes: reason,
    );
  }

  /// Replaces the item list. Test-only seam so the movement-result logic can
  /// be exercised without a live database.
  @visibleForTesting
  void debugSetItems(List<InventoryItem> items) {
    _items = List.of(items);
  }

  /// Exposes [_applyMovementResult] for tests.
  @visibleForTesting
  void debugApplyMovementResult(Map<String, dynamic> result, String itemId) =>
      _applyMovementResult(result, itemId);

  /// Exposes [_friendlyError] for tests.
  @visibleForTesting
  String debugFriendlyError(Object e) => _friendlyError(e);

  /// Exposes [_shouldFallbackLocally] for tests.
  @visibleForTesting
  bool debugShouldFallbackLocally(Object e) => _shouldFallbackLocally(e);

  /// Exposes [_serverCode] for tests.
  @visibleForTesting
  String? debugServerCode(Object e) => _serverCode(e);

  /// Apply the authoritative state returned by `apply_stock_movement`.
  ///
  /// The RPC runs the arithmetic under a row lock and returns the committed
  /// `left_count` / `total_in` / `total_sold`. That result is the truth - far
  /// better than re-reading the whole table, which was slow, could be blocked,
  /// and left the UI showing a stale count whenever the follow-up fetch failed.
  /// This is what makes the screen update with no manual refresh.
  void _applyMovementResult(Map<String, dynamic> result, String itemId) {
    final left = _asInt(result['left_count']);
    final totalIn = _asInt(result['total_in']);
    final totalSold = _asInt(result['total_sold']);
    final updatedBy = result['last_updated_by']?.toString();

    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1 || left == null) return;

    final item = _items[index];
    _items[index] = item.copyWith(
      leftCount: left,
      totalIn: totalIn ?? item.totalIn,
      totalSold: totalSold ?? item.totalSold,
      lastUpdated: DateTime.now(),
      lastUpdatedBy: updatedBy ?? item.lastUpdatedBy,
    );
  }

  /// PostgREST returns jsonb numerics as either int or double depending on the
  /// driver, so normalise before assigning to the int-typed model.
  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Pull in the freshly written transaction so the audit log updates too.
  ///
  /// Best-effort: the item count above is already correct from the RPC result,
  /// so a failure here only leaves the audit trail one row behind until the
  /// next realtime event or refresh. Also re-reads the item row: with 5-6
  /// devices writing concurrently, the follow-up read is the final guard that
  /// the screen matches the committed row even if the RPC payload was stale.
  Future<void> _reloadItemAndTxns(String itemId) async {
    try {
      final remoteItems = await _supabase.fetchInventory();
      if (remoteItems.isNotEmpty) {
        final fresh = remoteItems.firstWhere(
          (i) => i.id == itemId,
          orElse: () => _items.firstWhere((i) => i.id == itemId),
        );
        final index = _items.indexWhere((i) => i.id == itemId);
        if (index != -1) _items[index] = fresh;
      }
      final remoteTxns = await _supabase.fetchTransactions();
      if (remoteTxns.isNotEmpty) {
        _transactions = remoteTxns;
      }
      _syncStatusMessage = 'Saved & synced';
    } catch (e) {
      _syncStatusMessage = 'Saved & synced';
    }
    notifyListeners();
  }

  /// Turn database exceptions into something a warehouse operator can act on.
  ///
  /// Only a genuine transport failure may fall back to local arithmetic. A
  /// server that *answered* - even to refuse the request - must surface that
  /// answer, because falling back in that case lets the database silently
  /// disagree with what the screen shows.
  bool _shouldFallbackLocally(Object e) {
    final raw = e.toString();

    // A refusal from the server itself (rejected token, missing permission,
    // missing schema) is never an offline condition. Without this check a
    // genuine server error is turned into a local edit that looks saved.
    if (_isServerRefusal(e)) return false;

    if (raw.contains('Supabase is not configured')) return true;

    // A browser engine that refused the response is a CORS block: the request
    // never left the browser. Gated on kIsWeb so an Android operator is never
    // told to go and look at their browser.
    if (kIsWeb &&
        (raw.contains("'fetch' on 'Window'") ||
            raw.contains('CORS') ||
            raw.contains('blocked by the browser'))) {
      return true;
    }

    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return true;
    }
    if (raw.contains('NetworkException') || raw.contains('HandshakeException')) {
      return true;
    }
    if (raw.contains('ClientException')) return true;
    return false;
  }

  /// True when the server completed the request and refused it.
  ///
  /// postgrest signals every non-2xx response by throwing a
  /// `PostgrestException`, so its presence means a real HTTP status came back.
  /// Matched by name rather than by `is` so this file needs no postgrest
  /// import and still recognises the type if the plugin changes.
  static bool _isServerRefusal(Object e) =>
      e.toString().contains('PostgrestException');

  /// Pull the Postgres/PostgREST error code out of a postgrest exception.
  ///
  /// postgrest renders failures as
  /// `PostgrestException(message: ..., code: PGRST301, details: ..., hint: ...)`,
  /// where `code` is the Postgres code (PGRST202, P0001, 42501 ...) or the bare
  /// HTTP status when the body was not JSON.
  static String? _serverCode(Object e) =>
      RegExp(r'code:\s*([A-Za-z0-9_.]+)').firstMatch(e.toString())?.group(1);

  /// The server's own message, so the last-resort branch is never a dead end.
  static String? _serverMessage(Object e) {
    final raw = e.toString();
    if (!raw.contains('PostgrestException')) return null;
    final value =
        RegExp(r'message:\s*(.*?),\s*code:').firstMatch(raw)?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    return value.length > 180 ? '${value.substring(0, 180)}…' : value;
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    final code = _serverCode(e);

    // ---- Raised by apply_stock_movement() itself ------------------------
    if (raw.contains('INSUFFICIENT_STOCK')) {
      return 'Not enough stock left. Another device may have sold some already.';
    }
    if (raw.contains('AUTH_REQUIRED')) {
      return 'Session expired. Please sign in again.';
    }
    if (raw.contains('ITEM_NOT_FOUND')) {
      return 'Item not found on the server.';
    }
    if (raw.contains('INVALID_QUANTITY')) {
      return 'Invalid quantity.';
    }
    if (raw.contains('UNSUPPORTED_TYPE')) {
      return 'This kind of stock movement is not supported.';
    }

    // ---- Refusals from PostgREST / Supabase -----------------------------
    // PGRST301 is the important one. PostgREST answers a session token it
    // cannot verify with HTTP 401 and "No suitable key or wrong key type".
    // It used to fall through to the generic connectivity line below, which is
    // how a signing-key mismatch was reported to the operator as a dropped
    // connection - and why Android failed loudly while Chrome looked healthy.
    if (raw.contains('PGRST301')) {
      // This project verifies tokens against an asymmetric signing key
      // (ES256, see the public JWKS at /auth/v1/.well-known/jwks.json). The
      // app signs its own token with a shared secret, and an HS256 token can
      // NEVER verify against an ES256-only key set - hence "None of the keys
      // was able to decode the JWT". A malformed (newline) token or a wrong
      // secret also lands here, but the signing-key mismatch is the one that
      // survives both of those fixes.
      return 'This device\'s session token was rejected (PGRST301). This '
          'project verifies tokens with an asymmetric signing key (ES256), so '
          'a token the app signs with its own secret is not accepted. See '
          'SUPABASE_SETUP.md section 5.';
    }
    if (raw.contains('PGRST202')) {
      return 'Database schema is missing (PGRST202). Run 001_init.sql and '
          '002_seed.sql in the Supabase SQL Editor.';
    }
    if (raw.contains('PGRST116')) {
      return 'Item not found on the server.';
    }
    if (code == '42501' || lower.contains('permission denied')) {
      return 'This device is not permitted to change stock. Ask an admin to '
          'check the database grants.';
    }
    if (lower.contains('jwt') ||
        lower.contains('token is expired') ||
        lower.contains('invalid authentication credentials')) {
      return 'Session expired. Please sign out and sign in again.';
    }
    if (lower.contains('duplicate key')) {
      return 'A record with these details already exists.';
    }
    if (lower.contains('violates check constraint')) {
      return 'The server rejected these values as invalid.';
    }

    // HTTP 5xx: the database was reached but is erroring. postgrest reports a
    // non-JSON error page as a bare numeric status in `code`.
    if (code != null && RegExp(r'^5\d\d$').hasMatch(code)) {
      return 'The database returned a server error ($code). Try again shortly.';
    }

    // ---- Transport failures ---------------------------------------------
    // A browser engine that failed to return a response is a CORS block. That
    // happens on the web build and never on Android/iOS.
    if (kIsWeb &&
        (raw.contains("'fetch' on 'Window'") ||
            raw.contains('blocked by the browser'))) {
      return 'Blocked by the browser (CORS). Record sales works on a real '
          'device/emulator - run with: flutter run -d <device>.';
    }
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'No network connection. Check this device is online.';
    }
    if (raw.contains('ClientException') || raw.contains('HandshakeException')) {
      return 'Could not reach Supabase. Check the network and try again.';
    }

    // Last resort. Reporting the server's own message beats a generic "check
    // your connection" line that is wrong most of the time and tells neither
    // the operator nor whoever maintains the app what actually went wrong.
    final detail = _serverMessage(e);
    if (detail != null) return 'Could not save: $detail';
    return 'Could not save. Check your connection and try again.';
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  Future<void> saveItem(InventoryItem item) async {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      _items[index] = item;
    } else {
      _items.insert(0, item);
    }
    notifyListeners();

    if (_supabase.isConfigured) {
      // Await the write and report the outcome. This used to be
      // fire-and-forget, so a rejected catalogue edit (refused token, RLS, a
      // check constraint) produced no message at all and the change survived
      // only until the next refresh overwrote it.
      try {
        await _supabase.upsertItem(item);
        _lastError = null;
        _lastSaveReachedServer = true;
        _syncStatusMessage = 'Saved & synced';
      } catch (e) {
        debugPrint('InventoryProvider.saveItem failed: $e');
        _lastSaveReachedServer = false;
        _lastError = _friendlyError(e);
      }
      notifyListeners();
    }
  }
}
