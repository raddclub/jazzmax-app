import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_overlay.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _continueAsGuest() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).continueAsGuest();
      if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (e) {
      setState(() {
        _error = 'Cannot connect to server. Check your internet.';
        _loading = false;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).register(
        phone: _phoneCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      }
    } catch (e) {
      setState(() {
        _error = _extractError(e);
        _loading = false;
      });
    }
  }

  /// Extract the best human-readable error from any exception type.
  String _extractError(Object e) {
    // Try to get the server's JSON error message from a Dio response body
    try {
      // ignore: avoid_dynamic_calls
      final dynamic resp = (e as dynamic).response;
      if (resp != null) {
        final dynamic data = resp.data;
        if (data is Map && data['error'] != null) {
          return _friendlyError(data['error'].toString());
        }
        final int? status = resp.statusCode as int?;
        if (status != null) return _friendlyError(status.toString());
      }
    } catch (_) {}
    return _friendlyError(e.toString());
  }

  String _friendlyError(String raw) {
    if (raw.contains('409') || raw.contains('already')) {
      return 'This phone number is already registered. Please sign in instead.';
    }
    if (raw.contains('valid Jazz') || raw.contains('03')) {
      return raw; // Pass server validation messages through as-is
    }
    if (raw.contains('6 characters') || raw.contains('password')) {
      return raw;
    }
    if (raw.contains('connection') || raw.contains('SocketException') ||
        raw.contains('connect')) {
      return 'Cannot connect to server. Check your internet.';
    }
    // If it looks like a real server message (short, no stack trace), show it
    if (raw.length < 120 && !raw.contains('Exception') && !raw.contains('at ')) {
      return raw;
    }
    return 'Registration failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                const Text(
                  'Create Account',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Join RaddFlix — free for Jazz SIM users',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          hintText: '03001234567',
                          prefixIcon: Icon(Icons.phone_outlined,
                              color: AppColors.textMuted),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Enter your phone number';
                          }
                          if (v.trim().length < 10) {
                            return 'Enter a valid Pakistan phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: AppColors.textMuted),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Enter a password';
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscurePass,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline,
                              color: AppColors.textMuted),
                        ),
                        validator: (v) {
                          if (v != _passCtrl.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.error.withOpacity(0.4)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: const Text('Create Account'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _continueAsGuest,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.textMuted),
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Continue as Guest',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text.rich(
                      TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(color: AppColors.textMuted),
                        children: [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
