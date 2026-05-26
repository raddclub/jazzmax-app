import 'package:flutter/material.dart';
import 'models/catalog_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/constants.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/debug/debug_logger.dart';
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

// ── Navigation Observer ───────────────────────────────────────────────────────
class _DebugNavObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final name = route.settings.name ?? route.runtimeType.toString();
    final prev = previousRoute?.settings.name ?? 'none';
    DebugLogger.logNav(name, args: 'from=$prev');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final from = route.settings.name ?? route.runtimeType.toString();
    final to = previousRoute?.settings.name ?? 'none';
    DebugLogger.logNav('<back', args: 'popped=$from  backTo=$to');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final from = oldRoute?.settings.name ?? 'none';
    final to = newRoute?.settings.name ?? newRoute?.runtimeType.toString() ?? 'none';
    DebugLogger.logNav(to, args: 'replaced=$from');
  }
}

class ZenoApp extends ConsumerWidget {
  const ZenoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeProvider);
    DebugLogger.logUi('ZenoApp', 'build — themeMode=${themeState.mode}');
    Animate.restartOnHotReload = true;
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: JazzThemeData.build(themeState.mode),
      navigatorObservers: [_DebugNavObserver()],
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
          DebugLogger.logNav(AppRoutes.player,
              args: 'file_id=${args["file_id"]}  title=${args["title"]}');
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
          final item = settings.arguments as CatalogItem;
          DebugLogger.logNav(AppRoutes.showDetail,
              args: 'id=${item.id}  title=${item.title}');
          return PageRouteBuilder(
            pageBuilder: (_, __, ___) => ShowDetailScreen(item: item),
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
  bool _blocked = false;
  AppUpdateResult _result = AppUpdateResult.empty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  void _checkUpdate() {
    if (_checked) return;
    _checked = true;
    final r = AppUpdateService.lastResult;
    if ((r.forceUpdate || r.blocked) && mounted) {
      DebugLogger.logWarn('UPDATE', 'Force update or blocked: forceUpdate=${r.forceUpdate}  blocked=${r.blocked}  msg=${r.message}');
      setState(() { _blocked = true; _result = r; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_blocked) return _ForceUpdateScreen(result: _result);
    return widget.child;
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  final AppUpdateResult result;
  const _ForceUpdateScreen({required this.result});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Text(
                  'ZENO',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -2,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [Color(0xFF9D5FFF), Color(0xFF7B2FFF), Color(0xFF2F8BFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(const Rect.fromLTWH(0, 0, 150, 50)),
                  ),
                ),
                const SizedBox(height: 56),
                Container(
                  width: 110, height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.08),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.25), width: 2),
                  ),
                  child: Icon(
                    result.blocked
                        ? Icons.block_rounded
                        : Icons.system_update_alt_rounded,
                    color: AppColors.primary,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  result.blocked ? 'Access Blocked' : 'Update Required',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w800, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  result.message.isNotEmpty
                      ? result.message
                      : result.blocked
                          ? 'This version of ZENO is not authorized. Please download the official app.'
                          : 'A required update is available. Please update ZENO to continue watching.',
                  style: const TextStyle(
                      color: Color(0xFF9090B0), fontSize: 15, height: 1.65),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 52),
                if (!result.blocked && result.updateUrl.isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.tryParse(result.updateUrl);
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFFFF5757)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 24, offset: const Offset(0, 10),
                        )],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.download_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text('Update Now',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w800, fontSize: 16)),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF252540)),
                    ),
                    child: const Text('Contact Support',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9090B0),
                            fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                const SizedBox(height: 24),
                if (result.currentVersion.isNotEmpty)
                  Text('Latest version: ${result.currentVersion}',
                      style: const TextStyle(color: Color(0xFF505070), fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
