import 'package:flutter/foundation.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/operator_user.dart';

import 'supabase_service.dart';



/// Result of a PIN login attempt.

class AuthResult {

  final bool success;

  final String? error;



  const AuthResult.success() : success = true, error = null;

  const AuthResult.failure(this.error) : success = false;



  @override

  String toString() =>

      success ? 'AuthResult.success' : 'AuthResult.failure($error)';

}



/// PIN sign-in backed by a REAL Supabase Auth session.

///

/// WHY THIS EXISTS: the old design minted its own HS256 JWT in SQL

/// (operator_authenticate + Vault secret). Projects on Supabase's "JWT

/// Signing Keys" system verify every bearer token against an ES256 key set,

/// so PostgREST answered every authenticated call with 401 PGRST301

/// "No suitable key or wrong key type". No app or Vault change can fix that -
/// the signatures are of incompatible key types.
///
/// This class instead:
///   1. signs in anonymously with GoTrue (a token signed by Supabase itself,
///      so PostgREST accepts it);


///   2. call operator_bind_session(operator_id, pin, device...) which

///      verifies the bcrypt PIN and binds auth.uid() -> operator;

///   3. the SDK attaches the session to every query + Realtime channel

///      automatically - no manual Authorization header anywhere.

///

/// PREREQ: Dashboard -> Authentication -> Sign In/Up -> "Allow anonymous

/// sign-ins" ON, and supabase/007_anon_pin_binding.sql applied.

class AuthService extends ChangeNotifier {

  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;

  AuthService._internal();



  static const String _kSessionId = 'auth_session_id';

  static const String _kOperatorId = 'auth_operator_id';

  static const String _kDeviceId = 'auth_device_id';

  static const String _kDeviceLabel = 'auth_device_label';

  static const String _kLegacyToken = 'auth_token';



  // Legacy key from the old self-minted-JWT design (pre-007). Removed on

  // sign-out so a stale token can never sneak back into a request.

  // Removed: the SDK now manages the session token itself; no local JWT

  // exists to clear.



  OperatorUser? _operator;

  String? _sessionId;

  bool _restored = false;



  static String? _lastError;

  static String? get lastError => _lastError;

  static void clearLastError() => _lastError = null;



  OperatorUser? get currentOperator => _operator;

  String? get sessionId => _sessionId;

  bool get isAuthenticated => _operator != null;

  bool get isRestored => _restored;



  static String _newDeviceId() =>

      'dev_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';



  /// True while a Supabase Auth session exists (anonymous or otherwise).

  /// SupabaseService uses this to decide whether writes may be attempted.

  static bool get hasSession {

    try {

      return Supabase.instance.client.auth.currentSession != null;

    } catch (_) {

      return false;

    }

  }



  static String? _cachedDeviceId;

  static String? get cachedDeviceId => _cachedDeviceId;



  /// A device id is minted once and kept for the life of the install. A new

  /// id would make the server treat this device as a fresh one and close the

  /// previous sessions.

  static String _deviceId() => _cachedDeviceId ??= _newDeviceId();



  static Future<SupabaseClient> _client() async {

    final service = SupabaseService();

    final client = await service.ensureInitialized();

    if (client == null) {

      throw StateError('Supabase is not configured');

    }

    return client;

  }



  /// Restore a session after relaunch.

  ///

  /// The SDK has already restored the real (anonymous) Supabase session from

  /// its own storage by the time this runs, so this only re-derives the

  /// operator from the server via `operator_whoami`. Returns true when a

  /// valid PIN binding still exists.

  Future<bool> restoreSession() async {

    try {

      final prefs = await SharedPreferences.getInstance();

      _cachedDeviceId = prefs.getString(_kDeviceId);

      _sessionId = prefs.getString(_kSessionId);



      final client = await _client();

      if (client.auth.currentSession == null) {

        _restored = true;

        return false;

      }



      final data = await client.rpc('operator_whoami');

      final map =

          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

      if (map['ok'] != true || map['operator'] is! Map) {

        // The binding is gone (operator disabled, signed out elsewhere). Drop

        // the local state so the PIN screen returns.

        _restored = true;

        await clearSession();

        return false;

      }

      _operator =

          OperatorUser.fromJson(Map<String, dynamic>.from(map['operator']));

      _restored = true;

      notifyListeners();

      return true;

    } catch (e) {

      debugPrint('AuthService.restoreSession failed: $e');

      _restored = true;

      return false;

    }

  }



  /// Keep the server-side session row fresh so idle sessions can be reaped.

  Future<void> heartbeat() async {

    try {

      final client = await _client();

      await client.rpc('operator_heartbeat');

    } catch (e) {

      debugPrint('AuthService.heartbeat failed: $e');

    }

  }



  /// End the session server-side (best effort) and clear ALL local auth

  /// state, returning the device to the PIN screen.

  Future<void> signOut() async {

    try {

      final client = await _client();

      try {

        await client.rpc('operator_signout');

      } catch (e) {

        // Offline or already ended; the local clear below still matters.

        debugPrint('AuthService.signOut RPC failed (ignored): $e');

      }

      await client.auth.signOut();

    } catch (e) {

      debugPrint('AuthService.signOut failed: $e');

    }

    await clearSession();

  }



  /// Forget the local signed-in state and notify the AuthGate. No network

  /// calls are made so this is safe offline and in tests.

  Future<void> clearSession() async {

    _operator = null;

    _sessionId = null;

    try {

      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_kLegacyToken);

      await prefs.remove(_kOperatorId);

      await prefs.remove(_kSessionId);

      await prefs.remove(_kDeviceId);

      await prefs.remove(_kDeviceLabel);

    } catch (e) {

      debugPrint('AuthService.clearSession failed: $e');

    }

    notifyListeners();

  }



  /// Pull the operator roster for the PIN login screen.

  ///

  /// Runs while nobody is signed in (only the anon key exists), so it goes

  /// through the SECURITY DEFINER `list_operators` RPC and never through the

  /// RLS-protected table.

  Future<List<OperatorUser>> fetchOperators() async {

    try {

      final client = await _client();

      final data = await client.rpc('list_operators');

      _lastError = null;

      return (data as List)

          .map((row) => OperatorUser.fromJson(Map<String, dynamic>.from(row)))

          .toList();

    } catch (e) {

      debugPrint('AuthService.fetchOperators failed: $e');

      _lastError = e.toString();

      return const [];

    }

  }



  /// Verify the selected operator's PIN and bind the Supabase auth user to

  /// that operator on the server.

  ///

  /// Returns [AuthResult.success] only when the PIN was correct and the

  /// binding row was written. No token is minted here - see the class docs.

  Future<AuthResult> signIn({

    required OperatorUser operator,

    required String pin,

  }) async {

    try {

      final client = await _client();



      // 1) Ensure a REAL Supabase Auth session exists. On a fresh install

      //    that is an anonymous sign-in - a token signed by Supabase itself,

      //    which is what makes PostgREST accept it. On a relaunch the SDK has

      //    already restored the previous session, so this is a no-op.

      if (client.auth.currentSession == null) {
        // PIN-only login: the ONLY session source is an anonymous Supabase
        // Auth session (no email, no password, no extra screens anywhere).
        // Requires Dashboard -> Authentication -> "Allow anonymous sign-ins"
        // ON. When it is OFF there is no silent fallback - the operator gets
        // the exact toggle to flip instead of a cryptic "invalid email".
        final sessionError = await _ensureAnonymousSession(client);
        if (sessionError != null) return sessionError;
      }



      // 2) Verify the PIN and bind this auth user to the operator. The RPC is

      //    SECURITY DEFINER: it reads bcrypt hashes clients can never see and

      //    returns the operator profile only on a correct PIN.

      final data = await client.rpc('operator_bind_session', params: {

        'p_operator_id': operator.id,

        'p_pin': pin,

        'p_device_id': _deviceId(),

        'p_device_label': operator.deviceLabel,

      });

      final map =

          data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

      if (map['ok'] != true) {

        return AuthResult.failure(

            (map['error'] as String?) ?? 'Incorrect PIN.');

      }



      final opJson = map['operator'];

      if (opJson is! Map) {

        return const AuthResult.failure('Server returned a malformed operator.');

      }

      _operator = OperatorUser.fromJson(Map<String, dynamic>.from(opJson));

      _sessionId = map['session_id']?.toString() ?? _sessionId;



      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_kOperatorId, _operator!.id);

      await prefs.setString(_kSessionId, _sessionId ?? '');

      await prefs.setString(_kDeviceId, _deviceId());

      await prefs.setString(_kDeviceLabel, _operator!.deviceLabel);



      notifyListeners();

      return const AuthResult.success();

    } catch (e) {

      debugPrint('AuthService.signIn failed: $e');

      return const AuthResult.failure(

          'Login failed. Check the connection and try again.');

    }

  }

  /// Ensure an anonymous Supabase Auth session exists (the ONLY session source
  /// for PIN-only login). Returns null when a session now exists, otherwise an
  /// [AuthResult] failure naming the exact dashboard toggle to flip. There is
  /// deliberately no email/password fallback: the app is PIN-only, and a
  /// `@device.local` address is rejected by Supabase as invalid, which is the
  /// exact "could not start session ... invalid" error just reported.
  Future<AuthResult?> _ensureAnonymousSession(SupabaseClient client) async {
    try {
      final res = await client.auth.signInAnonymously();
      if (res.session == null && client.auth.currentSession == null) {
        return const AuthResult.failure(
            'Could not start a session. Check the connection and try again.');
      }
      return null;
    } on AuthException catch (e) {
      debugPrint('AuthService anonymous sign-in failed: $e');
      return AuthResult.failure(
        'Anonymous sign-in is disabled on this project. Enable '
        '"Allow anonymous sign-ins" in Supabase Dashboard -> Authentication '
        '-> Sign In/Up, then fully relaunch the app. ($e)',
      );
    }
  }

}




