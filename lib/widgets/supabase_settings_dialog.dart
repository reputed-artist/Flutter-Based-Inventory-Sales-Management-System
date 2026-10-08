import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/supabase_service.dart';
import '../providers/inventory_provider.dart';

class SupabaseSettingsDialog extends StatefulWidget {
  const SupabaseSettingsDialog({super.key});

  @override
  State<SupabaseSettingsDialog> createState() => _SupabaseSettingsDialogState();
}

class _SupabaseSettingsDialogState extends State<SupabaseSettingsDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _anonKeyController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  static const String _setupSql = '''
-- ---------------------------------------------------------------------------
--  Ink & Machine Sync - one-time backend setup
--
--  1) In the Supabase SQL Editor run these repo files, IN ORDER:
--        supabase/migrations/001_init.sql
--        supabase/migrations/002_seed.sql
--
--  2) Then store your project's JWT Secret in Vault so PIN login can sign
--     session tokens. Get it from: Project Settings -> API -> JWT Secret
--     (keep the legacy HS256 secret enabled).
-- ---------------------------------------------------------------------------
select vault.create_secret(
  '<PASTE_YOUR_JWT_SECRET_HERE>',
  'app_jwt_secret',
  'Ink & Machine Sync session-token signing key'
);

-- sanity check: should return true once the secret is stored
select public.jwt_secret() is not null as secret_ok;
''';

  @override
  void dispose() {
    _urlController.dispose();
    _anonKeyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    final anonKey = _anonKeyController.text.trim();

    if (url.isEmpty || anonKey.isEmpty) {
      setState(() => _errorMessage = 'Please enter both Supabase URL and Anon Key');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await SupabaseService().configure(url, anonKey);
    if (!mounted) return;

    setState(() => _isLoading = false);

    if (success) {
      await context.read<InventoryProvider>().refreshFromSupabase();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connected to Supabase Realtime! Multi-device sync is now active.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } else {
      setState(() => _errorMessage = 'Failed to connect. Check URL & Anon Key format.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = SupabaseService().isConfigured;

    return Dialog(
      backgroundColor: const Color(0xFF161F30),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 620),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.cloud_sync_rounded, color: Color(0xFF10B981), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Supabase Realtime Sync',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Connect all operator Android tablets and smartphones to the same Supabase database. Stock In, Sold data, and Left Counts update instantaneously across all devices.',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6), height: 1.4),
              ),
              const SizedBox(height: 16),

              if (isConnected) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Supabase Realtime is currently connected & syncing across devices.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await SupabaseService().disconnect();
                          setState(() {});
                        },
                        child: const Text('Disconnect', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else ...[
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Supabase Project URL',
                    hintText: 'https://your-project.supabase.co',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0D1424),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _anonKeyController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Supabase Anon Public API Key',
                    hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0D1424),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF334155))),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _isLoading ? null : _connect,
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('CONNECT SUPABASE DATABASE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // SQL Schema Setup Copy Helper
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1424),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Database Setup',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                        ),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(const ClipboardData(text: _setupSql));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied SQL schema to clipboard!')),
                            );
                          },
                          child: const Row(
                            children: [
                              Icon(Icons.copy_rounded, size: 14, color: Color(0xFF38BDF8)),
                              SizedBox(width: 4),
                              Text('Copy SQL', style: TextStyle(fontSize: 11, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'The full schema ships in supabase/migrations/ (001_init.sql + 002_seed.sql). Run those first, then paste this snippet to store your JWT secret. The complete steps are in SUPABASE_SETUP.md.',
                      style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
