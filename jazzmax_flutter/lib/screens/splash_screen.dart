import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    await ref.read(authProvider.notifier).checkAuth();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      } else if (next.status == AuthStatus.unauthenticated) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              _JazzMaxLogo(size: 72),
              const SizedBox(height: 24),
              // Tagline
              Text(
                AppConstants.tagline,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 64),
              // Loading indicator
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// JazzMAX logo: "Jazz" white + "MAX" red
class _JazzMaxLogo extends StatelessWidget {
  final double size;
  const _JazzMaxLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: size * 0.6,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
        children: const [
          TextSpan(
            text: 'Jazz',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          TextSpan(
            text: 'MAX',
            style: TextStyle(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
