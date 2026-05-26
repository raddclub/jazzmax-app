import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../core/remote_config.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  bool _started = false;

  // Particle animation
  late AnimationController _particleCtrl;

  // Logo reveal — each letter staggers in
  late AnimationController _logoCtrl;
  late List<Animation<double>> _letterFades;
  late List<Animation<double>> _letterSlides;
  late List<Animation<double>> _iconFades;

  // Wordmark fade-in after letters
  late AnimationController _wordCtrl;

  // Tagline + spinner
  late AnimationController _tagCtrl;

  static const _letters = ['Z', 'E', 'N', 'O'];
  static const _icons   = [Icons.play_arrow_rounded, Icons.remove_red_eye_outlined,
                            Icons.bolt_rounded, Icons.people_alt_outlined];
  static const _colors  = [AppColors.zColor, AppColors.eColor,
                            AppColors.nColor, AppColors.oColor];

  @override
  void initState() {
    super.initState();

    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))
      ..repeat();

    // Letters animate in over 1.6s total (400ms each, staggered)
    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _letterFades  = List.generate(4, (i) => CurvedAnimation(
      parent: _logoCtrl,
      curve: Interval(i * 0.15, i * 0.15 + 0.3, curve: Curves.easeOut),
    ));
    _letterSlides = List.generate(4, (i) => CurvedAnimation(
      parent: _logoCtrl,
      curve: Interval(i * 0.15, i * 0.15 + 0.35, curve: Curves.easeOutBack),
    ));
    _iconFades = List.generate(4, (i) => CurvedAnimation(
      parent: _logoCtrl,
      curve: Interval(i * 0.15 + 0.05, i * 0.15 + 0.35, curve: Curves.easeOut),
    ));

    _wordCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _tagCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _particleCtrl.forward();
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1800));
    _wordCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _tagCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await RemoteConfig.fetch();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final seen  = prefs.getBool(AppConstants.onboardingSeenKey) ?? false;
    if (!seen) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
      return;
    }
    await ref.read(authProvider.notifier).checkAuth();
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    _logoCtrl.dispose();
    _wordCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (!mounted || _started) return;
      if (next.status == AuthStatus.authenticated) {
        _started = true;
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
      } else if (next.status == AuthStatus.unauthenticated) {
        _started = true;
        Navigator.of(context).pushReplacementNamed(AppRoutes.login);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Particle field
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleCtrl,
              builder: (_, __) => CustomPaint(
                painter: _ParticlePainter(_particleCtrl.value),
              ),
            ),
          ),

          // Central glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.7,
                  colors: [
                    AppColors.primary.withOpacity(0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 3),

                // ── Letter icons row ──────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    return AnimatedBuilder(
                      animation: _logoCtrl,
                      builder: (_, __) {
                        final fade  = _iconFades[i].value;
                        final slide = _letterSlides[i].value;
                        return Opacity(
                          opacity: fade.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 10 * (1 - slide)),
                            child: _LetterIcon(
                              letter: _letters[i],
                              icon: _icons[i],
                              color: _colors[i],
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),

                const SizedBox(height: 28),

                // ── ZENO wordmark ─────────────────────────────────────────
                AnimatedBuilder(
                  animation: _wordCtrl,
                  builder: (_, __) {
                    return Opacity(
                      opacity: _wordCtrl.value,
                      child: Transform.scale(
                        scale: 0.92 + 0.08 * _wordCtrl.value,
                        child: _ZenoWordmark(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 14),

                // ── Tagline ───────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _tagCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _tagCtrl.value,
                    child: Transform.translate(
                      offset: Offset(0, 8 * (1 - _tagCtrl.value)),
                      child: Text(
                        AppConstants.tagline,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13.5,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Spinner ───────────────────────────────────────────────
                AnimatedBuilder(
                  animation: _tagCtrl,
                  builder: (_, __) => Opacity(
                    opacity: _tagCtrl.value,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary.withOpacity(0.8)),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Individual letter + icon widget ──────────────────────────────────────────
class _LetterIcon extends StatelessWidget {
  final String letter;
  final IconData icon;
  final Color color;
  const _LetterIcon({required this.letter, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon in colored circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.12),
              border: Border.all(color: color.withOpacity(0.35), width: 1.5),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.3), blurRadius: 18, spreadRadius: -2),
              ],
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          // Letter
          Text(
            letter,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              shadows: [Shadow(color: color.withOpacity(0.6), blurRadius: 12)],
            ),
          ),
        ],
      ),
    );
  }
}

// ── ZENO Wordmark ─────────────────────────────────────────────────────────────
class _ZenoWordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF9D5FFF), Color(0xFF7B2FFF), Color(0xFF2F8BFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Text(
        'ZENO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 68,
          fontWeight: FontWeight.w900,
          letterSpacing: -3,
          height: 1,
        ),
      ),
    );
  }
}

// ── Particle Painter ──────────────────────────────────────────────────────────
class _ParticlePainter extends CustomPainter {
  final double t;
  _ParticlePainter(this.t);

  static final _rng = math.Random(42);
  static final _particles = List.generate(55, (i) => [
    _rng.nextDouble(), // x ratio
    _rng.nextDouble(), // y ratio
    _rng.nextDouble() * 2.5 + 0.8, // size
    _rng.nextDouble(),              // speed offset
    _rng.nextInt(4).toDouble(),     // color index
  ]);

  static const _colors = [
    Color(0xFF7B2FFF), Color(0xFF2F8BFF),
    Color(0xFFE8002D), Color(0xFFFFD000),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final xBase = p[0] * size.width;
      final yBase = p[1] * size.height;
      final speed = p[3] * 0.3 + 0.1;
      final phase = (t * speed + p[3]) % 1.0;
      final dy    = -phase * size.height * 0.35;
      final alpha = (math.sin(phase * math.pi)).clamp(0.0, 1.0);
      final color = _colors[p[4].toInt()].withOpacity(alpha * 0.45);
      final paint = Paint()..color = color;
      canvas.drawCircle(Offset(xBase, yBase + dy), p[2], paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}
