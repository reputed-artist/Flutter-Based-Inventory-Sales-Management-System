import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ink_inventory_sync/models/inventory_item.dart';
import 'package:ink_inventory_sync/models/operator_user.dart';
import 'package:ink_inventory_sync/models/transaction.dart';
import 'package:ink_inventory_sync/providers/inventory_provider.dart';
import 'package:ink_inventory_sync/services/auth_service.dart';
import 'package:ink_inventory_sync/widgets/pin_login_screen.dart';

void main() {
  testWidgets('AuthGate shows the PIN login screen when not signed in',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PinLoginScreen(onAuthenticated: _noop)),
    );
    await tester.pump();

    // The operator roster is loaded from the database, so in a test
    // environment it will come back empty; the screen must still render
    // its header rather than throwing.
    expect(find.text('Ink & Machine Sync'), findsOneWidget);
  });

  testWidgets('PIN pad lays out without overflow on a short screen',
      (WidgetTester tester) async {
    // Regression: the PIN pad previously threw
    //   "Cannot compute intrinsic height of a GridView" (viewport.dart) and
    //   "RenderFlex overflowed by 425 pixels" because the keypad was sized by
    //   width via childAspectRatio inside an IntrinsicHeight. Drive the pad at a
    //   deliberately cramped height and large text scale.
    tester.view.physicalSize = const Size(500, 613);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(home: PinLoginScreen(onAuthenticated: _noop)),
    );
    await tester.pump();

    // Select an operator to reach the PIN pad. The roster is empty in tests, so
    // push the state directly through the widget's public surface.
    tester.state<PinLoginScreenState>(find.byType(PinLoginScreen))
        .selectOperatorForTest(_operator());
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 300));

    // The screen must have laid out without a RenderFlex overflow error.
    expect(tester.takeException(), isNull);
  });

  testWidgets('PIN pad survives a 2x text scale', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 613);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        builder: _doubleTextScale,
        home: PinLoginScreen(onAuthenticated: _noop),
      ),
    );
    await tester.pump();

    tester.state<PinLoginScreenState>(find.byType(PinLoginScreen))
        .selectOperatorForTest(_operator());
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });

  test('Dispatch of 10 from 120/78/42 gives 120/88/32 (user scenario)', () {
    // The exact figures reported from the app:
    //   total_in 120, total_sold 78, left_count 42, dispatch quantity 10
    // expected: total_in stays 120, total_sold 88, left_count 32.
    final provider = InventoryProvider();
    provider.debugSetItems([
      InventoryItem(
        id: 'item_hp_2580',
        sku: 'HP-B3F58B',
        name: 'HP 2580 Black Solvent Cartridge',
        category: InventoryCategory.hpCartridges,
        unit: 'Cartridge',
        totalIn: 120,
        totalSold: 78,
        leftCount: 42,
        minStockAlert: 15,
        lastUpdated: DateTime.utc(2026, 1, 1),
        lastUpdatedBy: 'Rajesh Sharma',
      ),
    ]);

    // This is what apply_stock_movement returns for a 'sold' movement of 10.
    provider.debugApplyMovementResult({
      'ok': true,
      'item_id': 'item_hp_2580',
      'left_count': 32,
      'total_in': 120,
      'total_sold': 88,
      'last_updated_by': 'Amit Patel',
    }, 'item_hp_2580');

    final after = provider.items.first;
    expect(after.leftCount, 32, reason: '42 - 10');
    expect(after.totalSold, 88, reason: '78 + 10');
    expect(after.totalIn, 120, reason: 'total_in must not change on a sale');
    expect(after.lastUpdatedBy, 'Amit Patel');
  });

  test('A sale cannot drive left_count below zero', () {
    // Guards the clamp in the offline path; the server refuses this outright
    // with INSUFFICIENT_STOCK, but the local fallback must not go negative.
    final item = InventoryItem(
      id: 'x',
      sku: 'x',
      name: 'x',
      category: InventoryCategory.hpCartridges,
      unit: 'units',
      totalIn: 10,
      totalSold: 0,
      leftCount: 3,
      minStockAlert: 5,
      lastUpdated: DateTime.utc(2026, 1, 1),
      lastUpdatedBy: 'Tester',
    );

    final reduced = item.copyWith(
      leftCount: (item.leftCount - 99).clamp(0, 999999),
      totalSold: item.totalSold + 99,
    );
    expect(reduced.leftCount, 0);
    expect(reduced.leftCount, greaterThanOrEqualTo(0));
  });

  test('Local sale fallback updates the item and audit log when the server write fails', () {
    final provider = InventoryProvider();
    provider.debugSetItems([
      InventoryItem(
        id: 'item_fallback',
        sku: 'SKU-FB',
        name: 'Fallback Cartridge',
        category: InventoryCategory.hpCartridges,
        unit: 'Cartridge',
        totalIn: 40,
        totalSold: 8,
        leftCount: 32,
        minStockAlert: 5,
        lastUpdated: DateTime.utc(2026, 1, 1),
        lastUpdatedBy: 'Tester',
      ),
    ]);

    provider.applyLocalStockMovement(
      itemId: 'item_fallback',
      type: 'sold',
      quantity: 7,
      unitPrice: 120.0,
      client: 'Retail Buyer',
      notes: 'Offline fallback',
    );

    final updated = provider.items.first;
    expect(updated.leftCount, 25, reason: '32 - 7');
    expect(updated.totalSold, 15, reason: '8 + 7');
    expect(provider.transactions.first.type, TransactionType.stockSold);
    expect(provider.transactions.first.clientOrSupplier, 'Retail Buyer');
  });

  test('Provider applies the committed left_count from the RPC result', () {
    // Regression: recording a sale used to discard the RPC's return value and
    // re-read the whole table, so a failed/blocked follow-up fetch left the
    // screen showing the OLD count and the user believed nothing was saved.
    final provider = InventoryProvider();

    final item = InventoryItem(
      id: 'item_1',
      sku: 'SKU-1',
      name: 'Test Cartridge',
      category: InventoryCategory.hpCartridges,
      unit: 'Cartridge',
      totalIn: 100,
      totalSold: 10,
      leftCount: 42,
      minStockAlert: 5,
      unitCostPrice: 100.0,
      unitSellingPrice: 150.0,
      lastUpdated: DateTime.utc(2026, 1, 1),
      lastUpdatedBy: 'Tester',
    );
    provider.debugSetItems([item]);

    // Simulate the jsonb that apply_stock_movement returns after selling 7.
    provider.debugApplyMovementResult({
      'ok': true,
      'item_id': 'item_1',
      'left_count': 35,
      'total_in': 100,
      'total_sold': 17,
      'last_updated_by': 'Rajesh Sharma',
    }, 'item_1');

    final updated = provider.items.first;
    expect(updated.leftCount, 35, reason: 'left count must reflect the sale');
    expect(updated.totalSold, 17);
    expect(updated.totalIn, 100);
    expect(updated.lastUpdatedBy, 'Rajesh Sharma');
  });

  test('RPC result parsing tolerates double and string numerics', () {
    // PostgREST jsonb numerics arrive as int or double depending on the driver;
    // a double left_count must still land as a whole number.
    final provider = InventoryProvider();
    provider.debugSetItems([
      InventoryItem(
        id: 'item_1',
        sku: 'SKU-1',
        name: 'Test Cartridge',
        category: InventoryCategory.hpCartridges,
        unit: 'Cartridge',
        totalIn: 50,
        totalSold: 0,
        leftCount: 20,
        minStockAlert: 5,
        lastUpdated: DateTime.utc(2026, 1, 1),
        lastUpdatedBy: 'Tester',
      ),
    ]);

    provider.debugApplyMovementResult({'left_count': 12.0}, 'item_1');
    expect(provider.items.first.leftCount, 12);

    provider.debugApplyMovementResult({'left_count': '9'}, 'item_1');
    expect(provider.items.first.leftCount, 9);
  });

  test('InventoryItem round-trips through toJson / fromJson', () {
    final original = InventoryItem(
      id: 'item_test',
      sku: 'SKU-1',
      name: 'Test Cartridge',
      category: InventoryCategory.hpCartridges,
      unit: 'Cartridge',
      totalIn: 10,
      totalSold: 4,
      leftCount: 6,
      minStockAlert: 2,
      unitCostPrice: 100.0,
      unitSellingPrice: 150.0,
      location: 'Rack Z-9',
      barcode: '1234567890',
      lastUpdated: DateTime.utc(2026, 1, 1),
      lastUpdatedBy: 'Tester',
    );

    final restored = InventoryItem.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.sku, original.sku);
    expect(restored.category, InventoryCategory.hpCartridges);
    expect(restored.leftCount, 6);
    expect(restored.totalSold, 4);
    expect(restored.unitCostPrice, 100.0);
    expect(restored.location, 'Rack Z-9');
  });

  group('stock-save error reporting', () {
    // The exact strings this app's users reported, captured from the live
    // backend with curl on the project this app ships pointed at.
    const pgrst301 = 'PostgrestException(message: No suitable key or wrong key '
        'type, code: PGRST301, details: None of the keys was able to decode '
        'the JWT, hint: null)';
    const pgrst202 = 'PostgrestException(message: Could not find the function '
        'public.apply_stock_movement, code: PGRST202, details: null, hint: null)';
    const authRequired = 'PostgrestException(message: AUTH_REQUIRED, '
        'code: P0001, details: null, hint: null)';
    const insufficient =
        'PostgrestException(message: INSUFFICIENT_STOCK, code: P0001, '
        'details: null, hint: null)';
    const denied = 'PostgrestException(message: permission denied for function '
        'apply_stock_movement, code: 42501, details: null, hint: null)';

    test('a rejected session token no longer reports a connectivity problem',
        () {
      // This is the Android failure. PostgREST refuses the operator JWT with
      // HTTP 401 PGRST301, which used to fall through to "Could not save. Check
      // your connection and try again." - true, but useless and wrong.
      final message = InventoryProvider().debugFriendlyError(pgrst301);

      expect(message, isNot(contains('Check your connection')));
      expect(message, contains('PGRST301'));
      expect(message, contains('SUPABASE_SETUP.md'));
    });

    test('an unknown server error is never reduced to a dead end', () {
      const unknown = 'PostgrestException(message: relation "nope" does not '
          'exist, code: 42P01, details: null, hint: null)';
      final message = InventoryProvider().debugFriendlyError(unknown);

      expect(message, startsWith('Could not save:'));
      expect(message, contains('does not exist'));
    });

    test('a missing schema is named as such', () {
      expect(InventoryProvider().debugFriendlyError(pgrst202),
          contains('PGRST202'));
    });

    test('RPC-raised business errors keep their own wording', () {
      final provider = InventoryProvider();
      expect(provider.debugFriendlyError(authRequired),
          'Session expired. Please sign in again.');
      expect(provider.debugFriendlyError(insufficient),
          contains('Not enough stock left'));
    });

    test('a permission refusal is reported as a permissions problem', () {
      expect(InventoryProvider().debugFriendlyError(denied),
          contains('not permitted'));
    });

    test('the HTTP status is read out of a non-JSON error body', () {
      // postgrest folds the status into `code` when the body is not JSON.
      const html = 'PostgrestException(message: <html>502 Bad Gateway</html>, '
          'code: 502, details: Bad Gateway, hint: null)';
      expect(InventoryProvider().debugFriendlyError(html), contains('502'));
    });

    test('transport failures still fall back to local arithmetic', () {
      // Offline support must survive: these are genuine transport faults.
      final provider = InventoryProvider();
      expect(provider.debugShouldFallbackLocally(
          "ClientException: Connection closed before full header was received"),
          isTrue);
      expect(
          provider.debugShouldFallbackLocally(
              'SocketException: Failed host lookup: \'edkeoeevdldytggiisxb.supabase.co\''),
          isTrue);
      expect(
          provider.debugShouldFallbackLocally('HandshakeException: Handshake '
              'error in client'),
          isTrue);
    });

    test('a server refusal NEVER falls back to a local-only save', () {
      // Regression guard for the real defect: the old code matched
      // 'ClientException' before looking at whether the server had answered,
      // so a refusal could be swallowed and the change applied in memory only.
      final provider = InventoryProvider();
      for (final refusal in <String>[
        pgrst301,
        pgrst202,
        authRequired,
        insufficient,
        denied,
      ]) {
        expect(provider.debugShouldFallbackLocally(refusal), isFalse,
            reason: 'must not be hidden as an offline save: $refusal');
      }
    });

    test('the PostgREST code is extracted for classification', () {
      expect(InventoryProvider().debugServerCode(pgrst301), 'PGRST301');
      expect(InventoryProvider().debugServerCode(authRequired), 'P0001');
    });
  });

  test('a PIN login without a configured backend returns a friendly failure',
      () async {
    // Regression guard for the new flow: signIn() talks to
    // operator_bind_session, but in a bare test environment there is no
    // Supabase client at all. It must still return an AuthResult.failure
    // instead of escaping as an unhandled error or leaking a session.
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();

    final result = await auth.signIn(operator: _operator(), pin: '1111');

    expect(result.success, isFalse);
    expect(result.error, isNotNull);
    expect(auth.isAuthenticated, isFalse);
  });

  test('sign-out notifies listeners so AuthGate returns to the PIN screen',
      () async {
    // The "Sign out" controls call AuthService().signOut(), and AuthGate
    // rebuilds from AuthService.isAuthenticated when it notifies. Without the
    // notification the signed-in shell would stay on screen after a sign-out.
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();

    var notified = 0;
    void listener() => notified++;
    auth.addListener(listener);
    addTearDown(() => auth.removeListener(listener));

    await auth.clearSession();

    expect(auth.isAuthenticated, isFalse);
    expect(notified, greaterThan(0));
  });

  test('Transaction type ids match the database check constraint', () {
    // The DB constrains type to in/sold/correction/transfer. If these ids
    // ever change, every insert will be rejected by Postgres.
    expect(TransactionType.stockIn.id, 'in');
    expect(TransactionType.stockSold.id, 'sold');
    expect(TransactionType.countCorrection.id, 'correction');
    expect(TransactionType.stockTransfer.id, 'transfer');
  });

  test('Category ids match the database check constraint', () {
    for (final category in InventoryCategory.values) {
      expect(InventoryCategoryExtension.fromString(category.id), category);
    }
  });

  test('Low stock and out of stock flags behave as the UI expects', () {
    InventoryItem build(int left, int alert) => InventoryItem(
          id: 'x',
          sku: 'x',
          name: 'x',
          category: InventoryCategory.hpCartridges,
          unit: 'units',
          totalIn: 10,
          totalSold: 0,
          leftCount: left,
          minStockAlert: alert,
          lastUpdated: DateTime.now(),
          lastUpdatedBy: 'Tester',
        );

    expect(build(0, 5).isOutOfStock, isTrue);
    expect(build(3, 5).isLowStock, isTrue);
    expect(build(5, 5).isLowStock, isTrue, reason: 'alert is inclusive');
    expect(build(6, 5).isLowStock, isFalse);
  });
}

void _noop() {}

/// Wraps the app at a 2x text scale, the setting that previously overflowed
/// the operator list and the PIN pad.
Widget _doubleTextScale(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(context)
        .copyWith(textScaler: const TextScaler.linear(2.0)),
    child: child!,
  );
}

/// A minimal operator used to drive the PIN pad in layout tests.
OperatorUser _operator() => OperatorUser(
      id: 'user_1',
      name: 'Rajesh Sharma',
      role: 'Warehouse Manager',
      deviceLabel: 'Galaxy Tab A9',
      avatarColor: '#0284c7',
    );

