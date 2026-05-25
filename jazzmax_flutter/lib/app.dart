import 'package:flutter/material.dart';
import 'models/catalog_item.dart';
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
import 'screens/show_detail_screen.dart';
import 'screens/vault_lock_screen.dart';
import 'screens/admin_queue_screen.dart';
import 'screens/vault_screen.dart';
import 'core/services/app_update_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
        AppRoutes.vault:         (_) => const VaultScreen(),
        AppRoutes.adminQueue:    (_) => const AdminQueueScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == AppRoutes.player) {
          final args = settings.arguments as Map<String, dynamic>;
          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => PlayerScreen(
              fileId: args['file_id'] as String,
              title: args['title'] as String,
              localPath: args['local_path'] as String?,
              episodes: args['episodes'] as List<Map<String, dynamic>>?,
              episodeIndex: args['episode_index'] as int? ?? 0,
            ),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: AppDurations.normal,
          );
        }
        if (settings.name == AppRoutes.showDetail) {
          final item = settings.arguments;
          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => ShowDetailScreen(item: item as CatalogItem),
            transitionsBuilder: (_, anim, __, child) =>
                SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
                      .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                  child: FadeTransition(opacity: anim, child: child),
                ),
            transitionDuration: const Duration(milliseconds: 350),
          );
        }
        if (settings.name == AppRoutes.vaultLock) {
          final args = settings.arguments as Map<String, dynamic>?;
          final isSetup = args?['setup'] == true;
          return MaterialPageRoute(
            builder: (_) => VaultLockScreen(isSetup: isSetup),
          );
        }
        return null;
      },
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.0)),
          child: _ForceUpdateGuard(child: child!),
        );
      },
    );
  }
}


class _ForceUpdateGuard extends StatefulWidget {
  final Widget child;
  const _ForceUpdateGuard({required this.child});
  @override
  State<_ForceUpdateGuard> createState() => _ForceUpdateGuardState();
}

class _ForceUpdateGuardState extends State<_ForceUpdateGuard> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  void _checkUpdate() {
    if (_checked) return;
    _checked = true;
    final r = AppUpdateService.lastResult;
    if ((r.forceUpdate || r.blocked) && r.message.isNotEmpty && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _UpdateDialog(result: r),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatelessWidget {
  final AppUpdateResult result;
  const _UpdateDialog({required this.result});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          const Icon(Icons.system_update_rounded, color: Color(0xFFE8002D), size: 24),
          const SizedBox(width: 10),
          Text(result.blocked ? 'App Blocked' : 'Update Required',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          result.message.isNotEmpty
              ? result.message
              : 'A required update is available. Please update JazzMAX to continue.',
          style: const TextStyle(color: Color(0xFFB0B0C0), fontSize: 14, height: 1.5),
        ),
        actions: [
          if (!result.blocked && result.updateUrl.isNotEmpty)
            TextButton(
              onPressed: () async {
                final uri = Uri.tryParse(result.updateUrl);
                if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: const Text('Update Now',
                  style: TextStyle(color: Color(0xFFE8002D), fontWeight: FontWeight.w700, fontSize: 15)),
            )
          else
            TextButton(
              onPressed: () {},
              child: const Text('OK', style: TextStyle(color: Color(0xFFE8002D))),
            ),
        ],
      ),
    );
  }
}
