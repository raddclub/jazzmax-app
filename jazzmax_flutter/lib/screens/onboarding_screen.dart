import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../core/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;

  static const List<_PageData> _pages = [
    _PageData(
      icon: Icons.wifi_off_rounded,
      iconColor: AppColors.oColor,
      title: 'Zero-Rated Streaming',
      body: 'Watch movies & shows on Jazz SIM without spending a single MB.\nZENO traffic is completely free.',
    ),
    _PageData(
      icon: Icons.play_arrow_rounded,
      iconColor: AppColors.zColor,
      title: 'Stream Everything',
      body: 'Movies, shows, dramas, anime — new titles added every week.\nYour entertainment, always growing.',
    ),
    _PageData(
      icon: Icons.bolt_rounded,
      iconColor: AppColors.nColor,
      title: 'Instant & Offline',
      body: 'Full catalog saved on your phone.\nBrowse, search and explore without any internet.',
    ),
    _PageData(
      icon: Icons.workspace_premium_rounded,
      iconColor: AppColors.primary,
      title: 'Dil Kholke Dekho',
      body: 'Start free. Upgrade to unlock HD quality,\npremium content and all titles.',
    ),
  ];

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingSeenKey, true);
    if (mounted) Navigator.of(context).pushReplacementNamed(AppRoutes.login);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated radial glow background
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.4,
                colors: [page.iconColor.withOpacity(0.12), AppColors.background],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: TextButton(
                      onPressed: _finish,
                      child: const Text('Skip',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (context, i) {
                      final p = _pages[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icon circle
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.iconColor.withOpacity(0.1),
                                border: Border.all(color: p.iconColor.withOpacity(0.3), width: 1.5),
                                boxShadow: [
                                  BoxShadow(color: p.iconColor.withOpacity(0.25),
                                      blurRadius: 40, spreadRadius: -5),
                                ],
                              ),
                              child: Icon(p.icon, color: p.iconColor, size: 50),
                            )
                                .animate(key: ValueKey('icon_$i'))
                                .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1),
                                    duration: 500.ms, curve: Curves.easeOutBack)
                                .fadeIn(duration: 400.ms),

                            const SizedBox(height: 44),

                            Text(
                              p.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            )
                                .animate(key: ValueKey('title_$i'), delay: 80.ms)
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.15, end: 0, duration: 400.ms,
                                    curve: Curves.easeOutCubic),

                            const SizedBox(height: 18),

                            Text(
                              p.body,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 15.5,
                                height: 1.65,
                                letterSpacing: 0.1,
                              ),
                              textAlign: TextAlign.center,
                            )
                                .animate(key: ValueKey('body_$i'), delay: 140.ms)
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.12, end: 0, duration: 400.ms,
                                    curve: Curves.easeOutCubic),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Page indicator
                AnimatedSmoothIndicator(
                  activeIndex: _page,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    dotHeight: 7,
                    dotWidth: 7,
                    expansionFactor: 3.5,
                    spacing: 5,
                    dotColor: AppColors.primary.withOpacity(0.25),
                    activeDotColor: AppColors.primary,
                  ),
                ),

                const SizedBox(height: 36),

                // CTA button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: GestureDetector(
                    onTap: isLast
                        ? _finish
                        : () => _ctrl.nextPage(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isLast
                              ? [AppColors.primary, AppColors.primaryLight]
                              : [AppColors.surfaceHigh, AppColors.card],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: isLast ? null
                            : Border.all(color: AppColors.glassBorder, width: 1),
                        boxShadow: isLast ? [
                          BoxShadow(color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 24, offset: const Offset(0, 8)),
                        ] : [],
                      ),
                      child: Text(
                        isLast ? 'Get Started' : 'Continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isLast ? Colors.white : AppColors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  const _PageData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });
}
