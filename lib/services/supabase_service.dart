import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory_item.dart';
import '../models/transaction.dart';
import 'auth_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient? _client;
  bool _isConfigured = false;
  RealtimeChannel? _itemsChannel;
  RealtimeChannel? _transactionsChannel;

  bool get isConfigured => _isConfigured;
  SupabaseClient? get client => _client;

  static const String _keyUrl = 'supabase_url';
  static const String _keyAnonKey = 'supabase_anon_key';

  /// Compile-time defaults so a device can be attached to a project with no
  /// in-app typing:
  ///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _envKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Allow this app to connect to Supabase again.
  static const bool _allowSupabaseConnection = true;

  /// The project this app ships pointed at. These are the public
  /// (publishable) project coordinates - they are safe to embed in a binary
  /// because Row Level Security, not the key, is what protects the data.
  ///
  /// Order of preference when connecting:
  ///   1. values saved in the in-app Supabase settings dialog
  ///   2. `--dart-define` values (use this to point a build elsewhere)
  ///   3. these defaults, so a fresh install connects with no setup
  static const String _defaultUrl = 'https://edkeoeevdldytggiisxb.supabase.co';
  static const String _defaultKey =
      'sb_publishable_mud9BiBIUG94TCJlnXIiJw_3g9dXnid';

  /// True when credentials are available from any source.
  bool get hasEnvDefaults => _envUrl.isNotEmpty && _envKey.isNotEmpty;

  /// True when Supabase is configured AND the SDK holds an auth session.
  ///
  /// The SDK attaches the session token to every REST call and Realtime
  /// channel automatically - there is no manual Authorization plumbing any
  /// more - so this decides whether server writes may be attempted.
  bool get isReady => _isConfigured && AuthService.hasSession;


  Future<void> initFromStorage() async {
    try {
      if (!_allowSupabaseConnection) {
        await disconnect();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final storedUrl = prefs.getString(_keyUrl);
      final storedKey = prefs.getString(_keyAnonKey);

      // Prefer credentials the operator saved in-app; then `--dart-define`
      // overrides; and finally the built-in defaults so the app is connected
      // the very first time it is opened.
      String pick(String? stored, String env, String fallback) {
        if (stored != null && stored.isNotEmpty) return stored;
        if (env.isNotEmpty) return env;
        return fallback;
      }

      final url = pick(storedUrl, _envUrl, _defaultUrl);
      final anonKey = pick(storedKey, _envKey, _defaultKey);

      if (url.isNotEmpty && anonKey.isNotEmpty) {
        await configure(url, anonKey, saveToPrefs: false);
      }
    } catch (e) {
      debugPrint('Error initializing Supabase from prefs: $e');
    }
  }

  /// Guarantee Supabase is configured before any client is handed out.
  ///
  /// The login screen needs `Supabase.instance.client` immediately on its
  /// first frame, which used to race the provider's asynchronous startup and
  /// produced an empty operator list. Every entry point now awaits this.
  Future<SupabaseClient?> ensureInitialized() async {
    if (_isConfigured && _client != null) return _client;
    await initFromStorage();
    return _client;
  }

  /// Connect and keep the credentials, so the app reconnects on every launch.
  Future<bool> configure(String url, String anonKey, {bool saveToPrefs = true}) async {
    try {
      if (url.isEmpty || anonKey.isEmpty) {
        _isConfigured = false;
        _client = null;
        return false;
      }

      try {
        await Supabase.initialize(
          url: url.trim(),
          publishableKey: anonKey.trim(),
          debug: kDebugMode,
          // v2.16.0 SDK: pass FlutterAuthClientOptions so the GoTrue client
          // starts the session auto-refresh lifecycle. Anonymous sign-ins are
          // enabled server-side (Dashboard -> Authentication -> Sign In/Up ->
          // Allow anonymous sign-ins ON), not by a client flag.
          authOptions: const FlutterAuthClientOptions(),
        );
      } catch (e) {
        // Hot restart / re-configure calls this twice in the same isolate.
        // Supabase.initialize() throws "already initialized" the second time
        // even though the existing client is perfectly usable. Treat that as
        // success instead of flipping the app into local-only mode (which is
        // exactly how working Chrome builds silently stopped persisting).
        final msg = e.toString().toLowerCase();
        if (!(msg.contains('already initialized') ||
            msg.contains('already been initialized'))) {
          rethrow;
        }
      }

      _client = Supabase.instance.client;
      _isConfigured = true;

      // Prove the REST API is actually reachable, and say so explicitly. A
      // silent "configured" flag is misleading: Supabase.initialize() only
      // constructs a client, it never touches the network, so the app can look
      // connected while every query is failing.
      unawaited(_probeConnection(url.trim()));

      if (saveToPrefs) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUrl, url.trim());
        await prefs.setString(_keyAnonKey, anonKey.trim());
      }
      return true;
    } catch (e) {
      debugPrint('Failed to configure Supabase: $e');
      _isConfigured = false;
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUrl);
      await prefs.remove(_keyAnonKey);
      _itemsChannel?.unsubscribe();
      _transactionsChannel?.unsubscribe();
      _client = null;
      _isConfigured = false;
    } catch (e) {
      debugPrint('Error disconnecting Supabase: $e');
    }
  }

  /// Log the parts of a failure that actually explain it.
  ///
  /// `debugPrint('$e')` on its own only ever shows the Dart message, which for
  /// a network fault reads like "Invalid value, uri=..." and gives no clue
  /// whether the server replied (401/403/500) or never replied at all (status
  /// code null). Logging the status, the Postgres error code and the raw body
  /// turns a guess into a diagnosis.
  static void _logNetworkFailure(String what, Object e) {
    debugPrint('--- Supabase failure: $what ---');
    debugPrint('  type    : ${e.runtimeType}');
    debugPrint('  message : $e');

    if (e is PostgrestException) {
      // postgrest 2.8.0 has no statusCode field; the HTTP status is folded
      // into the message, and `code` carries the Postgres error code (PGRSTxxx).
      debugPrint('  pgcode  : ${e.code}');
      debugPrint('  details : ${e.details}');
      debugPrint('  hint    : ${e.hint}');
      return;
    }
    // Any other throw here is the http package's transport-level failure, i.e.
    // the request left the device but no usable response came back. The type
    // name is read dynamically so this file does not need to import the http
    // package just for a type test.
    debugPrint('  network : no usable response came back (browser CORS block, '
        'offline, or DNS failure). type=${e.runtimeType}');
    debugPrint('  raw     : $e');
  }

  /// Fire a trivial authenticated query so connectivity problems surface once,
  /// at startup, with the real status code - instead of as a confusing failure
  /// deep inside whichever feature the operator happened to use first.
  ///
  /// Failure is logged only; the app stays usable offline.
  Future<void> _probeConnection(String url) async {
    // One probe is enough now: the SDK attaches the session token itself, so
    // there is no separate "manual auth header" path to test. The request
    // completing at all (even with an empty row set) proves the project is
    // reachable.
    try {
      await _client!.from('inventory_items').select('id').limit(1);
      debugPrint('Supabase: REST API reachable at $url '
          '(session present: ${AuthService.hasSession})');
    } catch (e) {
      debugPrint('Supabase: connectivity probe FAILED');
      _logNetworkFailure('connectivity probe', e);
    }
  }

  Future<List<InventoryItem>> fetchInventory() async {
    if (!_isConfigured || _client == null) return [];
    try {
      final response = await _client!
          .from('inventory_items')
          .select()
          .order('name', ascending: true);
      return (response as List)
          .map((row) => InventoryItem.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      _logNetworkFailure('fetchInventory', e);
      rethrow;
    }
  }

  Future<List<InventoryTransaction>> fetchTransactions() async {
    if (!_isConfigured || _client == null) return [];
    try {
      final response = await _client!
          .from('inventory_transactions')
          .select()
          .order('timestamp', ascending: false)
          .limit(100);
      return (response as List)
          .map((row) =>
              InventoryTransaction.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching transactions from Supabase: $e');
      rethrow;
    }
  }

  /// Apply a stock movement atomically on the server.
  ///
  /// The database performs the arithmetic under a row lock, writes the item
  /// row and the audit row in a single transaction, and stamps the record
  /// with the signed-in operator taken from the JWT. This is what prevents
  /// two devices selling the same SKU at the same moment from overwriting
  /// each other's counts.
  ///
  /// [quantity] is a delta for `in`/`sold` and the physical count for
  /// `correction`. Throws on insufficient stock or a missing item.
  Future<Map<String, dynamic>> applyStockMovement({
    required String itemId,
    required String type,
    required int quantity,
    double? unitPrice,
    String? client,
    String? notes,
  }) async {
    if (!_isConfigured || _client == null) {
      throw StateError('Supabase is not configured');
    }
    final data = await _client!.rpc('apply_stock_movement', params: {
      'p_item_id': itemId,
      'p_type': type,
      'p_quantity': quantity,
      'p_unit_price': unitPrice,
      'p_client': client,
      'p_notes': notes,
    });
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    if (map['ok'] != true) {
      // The RPC answered but refused the write (AUTH_REQUIRED, missing
      // binding, INSUFFICIENT_STOCK, ...). Throw so the provider shows the
      // server's own reason instead of closing the sheet as "synced" while
      // the database never changed.
      final reason = map['error']?.toString() ??
          map['message']?.toString() ??
          'Server refused the stock movement';
      debugPrint('apply_stock_movement returned ok=false: $map');
      throw StateError(reason);
    } else {
      // These are the keys the RPC actually returns (see 001_init.sql).
      debugPrint('apply_stock_movement committed: '
          'item=${map['item_id']} -> left_count=${map['left_count']}');
    }
    return map;
  }

  /// Push a locally-edited item row (used for catalogue field edits such as
  /// price, location and alert level - NOT for stock movements).
  Future<void> upsertItem(InventoryItem item) async {
    if (!_isConfigured || _client == null) return;
    try {
      await _client!.from('inventory_items').upsert(item.toJson());
    } catch (e) {
      debugPrint('Error upserting item: $e');
      rethrow;
    }
  }

  Future<void> logTransaction(InventoryTransaction transaction) async {
    if (!_isConfigured || _client == null) return;
    try {
      await _client!
          .from('inventory_transactions')
          .insert(transaction.toJson());
    } catch (e) {
      debugPrint('Error inserting transaction: $e');
      rethrow;
    }
  }

  void subscribeToRealtimeUpdates({
    required Function(Map<String, dynamic> payload) onItemUpdated,
    required Function(Map<String, dynamic> payload) onTransactionInserted,
  }) {
    if (!_isConfigured || _client == null) return;

    // The SDK attaches the current session's token to the websocket itself,
    // so the Realtime RLS checks pass and each device only receives rows it
    // is allowed to see. No manual setAuth is needed.

    // Drop any previous channels first, otherwise repeated sign-ins would
    // leave stale, unauthenticated channels attached and every event would
    // be delivered twice (or not at all).
    for (final stale in [_itemsChannel, _transactionsChannel]) {
      if (stale != null) {
        _client!.removeChannel(stale);
      }
    }

    _itemsChannel = _client!
        .channel('public:inventory_items')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'inventory_items',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              onItemUpdated(Map<String, dynamic>.from(record));
            }
          },
        )
        .subscribe();

    _transactionsChannel = _client!
        .channel('public:inventory_transactions')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'inventory_transactions',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) {
              onTransactionInserted(Map<String, dynamic>.from(record));
            }
          },
        )
        .subscribe();
  }
}

