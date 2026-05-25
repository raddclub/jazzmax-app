import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/jazz_text_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;
  String? _error;

  @override
  void dispose() { _phoneCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).login(
        phone: _phoneCtrl.text.trim(), password: _passCtrl.text);
      if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (e) {
      setState(() { _error = _friendly(e.toString()); _loading = false; });
    }
  }

  Future<void> _guest() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authProvider.notifier).continueAsGuest();
      if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (e) {
      setState(() { _error = 'Cannot connect. Check your internet.'; _loading = false; });
    }
  }

  String _friendly(String raw) {
    if (raw.contains('401') || raw.contains('Invalid')) return 'Wrong phone or password.';
    if (raw.contains('SocketException') || raw.contains('connection')) return 'No internet connection.';
    return 'Login failed. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      loading: _loading,
      child: Scaffold(
        backgroundColor: null,
        body: Stack(
          children: [
            // Background glow
            Positioned(
              top: -100, left: -80,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [AppColors.primary.withOpacity(0.15), Colors.transparent],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),
                    // Logo
                    Center(child: _Logo())
                        .animate().fadeIn(duration: 500.ms)
                        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1),
                            duration: 500.ms, curve: AppCurves.enter),
                    const SizedBox(height: 48),
                    Text('Welcome back',
                        style: TextStyle(
                          color: AppColors.textMuted, fontSize: 14, letterSpacing: 0.3))
                        .animate(delay: 100.ms).fadeIn(duration: 400.ms),
                    const SizedBox(height: 4),
                    const Text('Sign In',
                        style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 28,
                          fontWeight: FontWeight.w800, letterSpacing: -0.5))
                        .animate(delay: 150.ms).fadeIn(duration: 400.ms)
                        .slideX(begin: -0.2, end: 0, duration: 400.ms, curve: AppCurves.standard),
                    const SizedBox(height: 28),
                    Form(
                      key: _formKey,
                      child: Column(children: [
                        JazzTextField(
                          controller: _phoneCtrl,
                          label: 'Phone Number',
                          hint: '03001234567',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone_outlined,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter your phone number';
                            return null;
                          },
                        ).animate(delay: 200.ms).fadeIn(duration: 350.ms)
                            .slideY(begin: 0.2, end: 0, duration: 350.ms, curve: AppCurves.standard),
                        const SizedBox(height: 14),
                        JazzTextField(
                          controller: _passCtrl,
                          label: 'Password',
                          obscureText: _obscure,
                          prefixIcon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.textMuted, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Enter your password';
                            return null;
                          },
                        ).animate(delay: 260.ms).fadeIn(duration: 350.ms)
                            .slideY(begin: 0.2, end: 0, duration: 350.ms, curve: AppCurves.standard),
                      ]),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: _error!)
                          .animate().fadeIn(duration: 250.ms).shakeX(hz: 3, amount: 4),
                    ],
                    const SizedBox(height: 28),
                    // Sign In Button
                    _GradientButton(label: 'Sign In', onTap: _loading ? null : _login)
                        .animate(delay: 320.ms).fadeIn(duration: 350.ms)
                        .slideY(begin: 0.2, end: 0, duration: 350.ms, curve: AppCurves.standard),
                    const SizedBox(height: 12),
                    // Guest
                    OutlinedButton(
                      onPressed: _loading ? null : _guest,
                      child: const Text('Continue as Guest'),
                    )
                        .animate(delay: 370.ms).fadeIn(duration: 350.ms),
                    const SizedBox(height: 24),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pushNamed(AppRoutes.register),
                        child: Text.rich(
                          TextSpan(
                            text: "Don't have an account? ",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                            children: [
                              TextSpan(text: 'Register',
                                  style: const TextStyle(
                                      color: AppColors.primary, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ),
                    ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFE8002D), Color(0xFF8B0000)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            boxShadow: AppShadows.glow,
          ),
          child: const Center(
            child: Text('J', style: TextStyle(
              color: Colors.white, fontSize: 32,
              fontWeight: FontWeight.w900, letterSpacing: -1)),
          ),
        ),
        const SizedBox(height: 14),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1),
            children: [
              TextSpan(text: 'Jazz', style: TextStyle(color: AppColors.textPrimary)),
              TextSpan(text: 'MAX', style: TextStyle(color: AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.error.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(message,
              style: const TextStyle(color: AppColors.error, fontSize: 13))),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _GradientButton({required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: onTap != null ? AppColors.primaryGradient : null,
        color: onTap == null ? AppColors.primary.withOpacity(0.4) : null,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: onTap != null ? AppShadows.primary : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Center(
            child: Text(label,
              style: const TextStyle(
                color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ),
        ),
      ),
    );
  }
}
