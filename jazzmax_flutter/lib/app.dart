import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/player_screen.dart';
import 'screens/subscription_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/search_screen.dart';

class JazzMaxApp extends ConsumerWidget {
  const JazzMaxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    Animate.restartOnHotReload = true;
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: JazzThemeData.build(themeState.mode),
      initialRoute: AppRoutes.splash,
      routes: {
        AppRoutes.splash:       (_) => const SplashScreen(),
        AppRoutes.onboarding:   (_) => const OnboardingScreen(),
        AppRoutes.login:        (_) => const LoginScreen(),
        AppRoutes.register:     (_) => const RegisterScreen(),
        AppRoutes.home:         (_) => const HomeScreen(),
        AppRoutes.subscription: (_) => const SubscriptionScreen(),
        AppRoutes.profile:      (_) => const ProfileScreen(),
        AppRoutes.downloads:    (_) => const DownloadsScreen(),
        AppRoutes.search:       (_) => const SearchScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.player) {
          final args = settings.arguments as Map<String, dynamic>;
          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => PlayerScreen(
              fileId: args['file_id'] as String,
              title: args['title'] as String,
              localPath: args['local_path'] as String?,
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: AppDurations.normal,
          );
        }
        return null;
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: child!,
        );
      },
    );
  }
}
