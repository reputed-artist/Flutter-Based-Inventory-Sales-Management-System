import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/inventory_provider.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/audit_screen.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'widgets/pin_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Connect to Supabase BEFORE the first frame is built. The login screen
  // queries the operator roster on its first frame, so initialising here
  // (rather than lazily inside the provider) is what keeps that list from
  // rendering empty, and guarantees the app is connected once opened.
  await SupabaseService().ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InventoryProvider()),
      ],
      child: const InventorySyncApp(),
    ),
  );
}

/// Gates the app behind PIN authentication.
///
/// Shows a brief splash while any previously stored session is restored,
/// then either the PIN login screen or the normal app shell. The existing
/// UI is untouched - this only decides which of the two is on screen.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    // React to sign-in/sign-out from anywhere in the app. This is what makes
    // the "Sign out" controls (app bar / user switcher) return the device to
    // the PIN screen without those widgets needing a reference to this gate.
    _auth.addListener(_onAuthChanged);
    _restore();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    setState(() {}); // rebuild from _auth.isAuthenticated
  }

  Future<void> _restore() async {
    final ok = await _auth.restoreSession();
    if (!mounted) return;
    setState(() => _checking = false);
    if (ok) {
      await context.read<InventoryProvider>().bindToSession();
    }
  }

  Future<void> _onAuthenticated() async {
    // AuthService.signIn already set the operator and notified listeners, so
    // the shell appears on its own; this only binds the data provider.
    await context.read<InventoryProvider>().bindToSession();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F17),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }

    // The signed-in state is read from the service itself, so a sign-out
    // performed anywhere brings the PIN screen straight back.
    if (!_auth.isAuthenticated) {
      return PinLoginScreen(onAuthenticated: _onAuthenticated);
    }

    return const MainNavigationShell();
  }
}


class InventorySyncApp extends StatelessWidget {
  const InventorySyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ink & Machine Inventory Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF0284C7),
          secondary: Color(0xFF38BDF8),
          surface: Color(0xFF161F30),
          error: Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSurface: Colors.white,
        ),
        fontFamily: 'Roboto',
      ),
      home: const AuthGate(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    InventoryScreen(),
    ReportsScreen(),
    AuditScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          border: Border(top: BorderSide(color: Color(0xFF1E293B))),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: const Color(0xFF0284C7).withValues(alpha: 0.2),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() => _currentIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.inventory_2_rounded, color: Color(0xFF38BDF8)),
              label: 'Stock Items',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.bar_chart_rounded, color: Color(0xFF38BDF8)),
              label: 'Reports',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_edu_outlined, color: Color(0xFF94A3B8)),
              selectedIcon: Icon(Icons.history_edu_rounded, color: Color(0xFF38BDF8)),
              label: 'Audit Log',
            ),
          ],
        ),
      ),
    );
  }
}
