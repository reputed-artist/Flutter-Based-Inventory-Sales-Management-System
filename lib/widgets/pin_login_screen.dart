import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/operator_user.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';
import 'supabase_settings_dialog.dart';

/// PIN login screen.
///
/// Shows the operator list, then a 4-digit PIN pad. Visually consistent
/// with the rest of the app (same dark palette and card styling as
/// `SupabaseSettingsDialog`), so it reads as a native part of the UI.
class PinLoginScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const PinLoginScreen({super.key, required this.onAuthenticated});

  @override
  PinLoginScreenState createState() => PinLoginScreenState();
}

/// Public so widget tests can drive the PIN pad directly (see test/).
class PinLoginScreenState extends State<PinLoginScreen> {
  final AuthService _auth = AuthService();

  List<OperatorUser> _operators = const [];
  OperatorUser? _selected;
  String _pin = '';
  bool _isLoadingList = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOperators();
  }

  Future<void> _loadOperators() async {
    setState(() {
      _isLoadingList = true;
      _error = null;
    });
    AuthService.clearLastError();

    final list = await _auth.fetchOperators();
    if (!mounted) return;

    setState(() {
      _operators = list;
      _isLoadingList = false;
      if (list.isEmpty) {
        // The roster comes from the `list_operators()` RPC, so an empty result
        // means either the schema was never applied or the seed is empty -
        // not that the query failed. `lastError` says which.
        _error = AuthService.lastError ??
            (SupabaseService().isConfigured
                ? 'No operators found in the database. Run 002_seed.sql in '
                    'Supabase, then tap Retry.'
                : 'Not connected to Supabase yet. Tap Retry.');
      }
    });
  }

  /// Pull the roster again, e.g. after applying the seed or fixing the URL.
  void _retry() {
    _loadOperators();
  }

  void _appendDigit(String digit) {
    if (_pin.length >= 4 || _isSubmitting) return;
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      _pin += digit;
    });
    if (_pin.length == 4) {
      _submit();
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty || _isSubmitting) return;
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _submit() async {
    final operator = _selected;
    if (operator == null) return;

    setState(() => _isSubmitting = true);
    final result = await _auth.signIn(operator: operator, pin: _pin);
    if (!mounted) return;

    if (result.success) {
      HapticFeedback.mediumImpact();
      widget.onAuthenticated();
      return;
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _isSubmitting = false;
      _error = result.error ?? 'Login failed.';
      _pin = '';
    });
  }

  void _backToList() {
    setState(() {
      _selected = null;
      _pin = '';
      _error = null;
    });
  }


  Widget _buildOperatorList() {
    // Whole screen scrolls as one column. Previously the footer (error text +
    // "Configure Supabase Database" button) sat below an Expanded ListView, so
    // at a large text scale the footer grew past the window and the Column
    // overflowed. With mainAxisSize.min inside a scroll view nothing can
    // overflow - the entire screen simply scrolls.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 40, 24, 8),
          child: Column(
            children: [
              Icon(Icons.inventory_2_rounded, color: Color(0xFF38BDF8), size: 44),
              SizedBox(height: 14),
              Text(
                'Ink & Machine Sync',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Select your name to start a data entry session',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        _isLoadingList
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                ),
              )
            : ListView.builder(
                // shrinkWrap inside the screen-level scroll view: the roster is
                // short (a handful of operators), so it is cheaper to lay the
                // whole thing out than to nest a second scrollable.
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: _operators.length,
                itemBuilder: (context, index) {
                  final op = _operators[index];
                  // Material (not a decorated Container) so ListTile's ink
                  // splashes and background land on THIS widget instead of
                  // an ancestor, which the framework asserts against.
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0xFF161F30),
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: Ink(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _parseColor(op.avatarColor),
                              child: Text(
                                op.name.substring(0, 1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            title: Text(
                              op.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              '${op.role} • ${op.deviceLabel}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFF38BDF8),
                            ),
                            onTap: () => setState(() {
                              _selected = op;
                              _pin = '';
                              _error = null;
                            }),
                              ),
                            ),
                          ),
                );
              },
            ),
            if (_error != null)
              Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Column(
              children: [
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _isLoadingList ? null : _retry,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Color(0xFF38BDF8), size: 18),
                  label: const Text(
                    'Retry',
                    style: TextStyle(
                        color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        // First-run / recovery entry point: lets an operator point this device
        // at a Supabase project before any operators exist to sign in as.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              TextButton.icon(
                onPressed: _openSupabaseConfig,
                icon: const Icon(Icons.cloud_sync_rounded,
                    color: Color(0xFF38BDF8), size: 18),
                label: const Text(
                  'Configure Supabase Database',
                  style: TextStyle(
                      color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                SupabaseService().isConfigured
                    ? 'Connected - enter a PIN to continue'
                    : 'No database yet? Tap above to paste your Supabase URL & anon key.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Open the Supabase connection dialog, then reload the operator roster so
  /// the list appears immediately after a successful connection.
  Future<void> _openSupabaseConfig() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const SupabaseSettingsDialog(),
    );
    await _loadOperators();
  }

  /// Parse the "#rrggbb" strings stored in the operators table.
  Color _parseColor(String hex) {
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return const Color(0xFF0284C7);
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return const Color(0xFF0284C7);
    return Color(0xFF000000 | value);
  }

  Widget _buildPinPad() {
    final op = _selected!;

    // A plain Column inside a scroll view. The scroll view hands the child an
    // unbounded height, so the column can NEVER overflow - on a short window
    // or at a 2x text scale it simply scrolls.
    //
    // Two earlier attempts failed here, both worth remembering:
    //  * IntrinsicHeight asked the GridView for an intrinsic height. A viewport
    //    cannot supply one, so Flutter asserted in viewport.dart.
    //  * ConstrainedBox(minHeight: available) made the height tight, which
    //    reintroduced a 32px RenderFlex overflow, because a tight height
    //    cannot be exceeded - it clips and throws.
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildPinHeader(op),
          _buildPinDots(),
          _buildPinStatus(),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
            child: _buildKeypad(),
          ),
        ],
      ),
    );
  }

  /// Jumps straight to the PIN pad for [op]. Used by widget tests, which have
  /// no database roster to tap through.
  @visibleForTesting
  void selectOperatorForTest(OperatorUser op) {
    setState(() {
      _selected = op;
      _pin = '';
      _error = null;
    });
  }

  /// Back button + the selected operator's name and role.
  Widget _buildPinHeader(OperatorUser op) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF94A3B8)),
            onPressed: _isSubmitting ? null : _backToList,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    op.name,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    op.role,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The "Enter 4-digit PIN" caption and the four progress dots.
  Widget _buildPinDots() {
    return Column(
      children: [
        const SizedBox(height: 28),
        Text(
          'Enter 4-digit PIN',
          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (i) {
            final filled = i < _pin.length;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled ? const Color(0xFF38BDF8) : Colors.transparent,
                border: Border.all(
                  color: filled ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                  width: 2,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  /// Spinner while the PIN is being verified, or the error text.
  ///
  /// The height is a MINIMUM, not a fixed box: at a large text scale the error
  /// message wraps to more lines and a fixed height would overflow.
  Widget _buildPinStatus() {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 20),
      child: Center(
        child: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF38BDF8),
                ),
              )
            : (_error != null
                ? Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontSize: 12),
                  )
                : null),
      ),
    );
  }

  Widget _buildKeypad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '\u232B'];

    // A Wrap of fixed-height buttons rather than a GridView: GridView is a
    // viewport, so it cannot report an intrinsic size (which is what broke
    // IntrinsicHeight), and its height would be driven by the width instead of
    // the space actually available for it.
    const spacing = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 3;
        final buttonWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          alignment: WrapAlignment.center,
          runSpacing: spacing,
          spacing: spacing,
          children: [
            for (final key in keys)
              if (key.isEmpty)
                SizedBox(width: buttonWidth, height: _keyHeight)
              else
                SizedBox(
                  width: buttonWidth,
                  height: _keyHeight,
                  child: _buildKeyButton(key),
                ),
          ],
        );
      },
    );
  }

  static const double _keyHeight = 56;

  Widget _buildKeyButton(String key) {
    final isBackspace = key == '\u232B';
    return Material(
      color: const Color(0xFF161F30),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => isBackspace ? _removeDigit() : _appendDigit(key),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          alignment: Alignment.center,
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F17),
      body: SafeArea(
        child: _selected == null ? _buildOperatorList() : _buildPinPad(),
      ),
    );
  }
}
