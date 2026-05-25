import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'JazzMAX';
  static const String tagline = 'Pakistan ka entertainment, data-free';

  /// Runtime-mutable: updated by RemoteConfig.fetch() on every app start.
  static String apiBaseUrl = 'http://92.4.95.252';

  static const String onboardingSeenKey = 'jm_onboarding_seen';

  static const Duration accessTokenValidity = Duration(minutes: 15);
  static const Duration refreshTokenValidity = Duration(days: 90);

  static const Duration catalogSyncInterval = Duration(hours: 6);
  static const String catalogDbName = 'jazzmax_catalog.db';
  static const int catalogDbVersion = 8;
  static const int streamCacheTtlSeconds = 21600;
}

// ── Brand Colors ─────────────────────────────────────────────────────────────
class AppColors {
  // Primary brand
  static const Color primary       = Color(0xFFE8002D);
  static const Color primaryDark   = Color(0xFFB5001F);
  static const Color primaryGlow   = Color(0x40E8002D);
  static const Color primaryLight  = Color(0xFFFF4D6A);

  // Backgrounds (Dark theme)
  static const Color background    = Color(0xFF08080E);
  static const Color backgroundAlt = Color(0xFF0D0D1A);
  static const Color surface       = Color(0xFF0E0E1C);
  static const Color surfaceHigh   = Color(0xFF161628);
  static const Color card          = Color(0xFF1A1A2E);
  static const Color cardBorder    = Color(0xFF252540);

  // Glassmorphism
  static const Color glass         = Color(0x0DFFFFFF);
  static const Color glassBorder   = Color(0x14FFFFFF);
  static const Color glassHigh     = Color(0x1AFFFFFF);

  // AMOLED backgrounds
  static const Color amoled        = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0A0A0A);
  static const Color amoledCard    = Color(0xFF111111);

  // Light theme
  static const Color lightBg       = Color(0xFFF0F0F7);
  static const Color lightSurface  = Color(0xFFFFFFFF);
  static const Color lightCard     = Color(0xFFF5F5FA);
  static const Color lightBorder   = Color(0xFFE0E0EC);

  // Text
  static const Color textPrimary   = Color(0xFFF2F2FF);
  static const Color textSecondary = Color(0xFFB0B0CC);
  static const Color textMuted     = Color(0xFF6A6A90);
  static const Color textDisabled  = Color(0xFF404060);

  // Text (light mode)
  static const Color lightTextPrimary   = Color(0xFF0A0A1A);
  static const Color lightTextSecondary = Color(0xFF444466);
  static const Color lightTextMuted     = Color(0xFF888899);

  // Shorthand aliases used across screens
  static const Color text      = textPrimary;
  static const Color border    = glassBorder;

  // Status
  static const Color success       = Color(0xFF22C55E);
  static const Color successGlow   = Color(0x2222C55E);
  static const Color error         = Color(0xFFEF4444);
  static const Color errorGlow     = Color(0x22EF4444);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color warningGlow   = Color(0x22F59E0B);
  static const Color info          = Color(0xFF3B82F6);

  // Divider
  static const Color divider       = Color(0xFF1E1E35);
  static const Color dividerLight  = Color(0xFFE0E0F0);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE8002D), Color(0xFFFF5C5C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF08080E), Color(0xFF0D0D22)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xFF08080E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.3, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF161628), Color(0xFF0E0E1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── Shadows ───────────────────────────────────────────────────────────────────
class AppShadows {
  static List<BoxShadow> get primary => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.3),
      blurRadius: 20,
      spreadRadius: -4,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 24,
      spreadRadius: -8,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: AppColors.primary.withOpacity(0.05),
      blurRadius: 40,
      spreadRadius: -10,
    ),
  ];

  static List<BoxShadow> get soft => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 16,
      spreadRadius: -4,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get glow => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.4),
      blurRadius: 30,
      spreadRadius: -5,
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: Colors.black.withOpacity(0.6),
      blurRadius: 40,
      spreadRadius: -10,
      offset: const Offset(0, 20),
    ),
  ];
}

// ── Durations ─────────────────────────────────────────────────────────────────
class AppDurations {
  static const Duration fast   = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow   = Duration(milliseconds: 280);
  static const Duration xslow  = Duration(milliseconds: 420);
}

// ── Curves ────────────────────────────────────────────────────────────────────
class AppCurves {
  static const Curve standard = Curves.easeOutCubic;
  static const Curve enter    = Curves.easeOutExpo;
  static const Curve exit     = Curves.easeInQuart;
  static const Curve spring   = Curves.easeOutBack;
  static const Curve bounce   = Curves.bounceOut;
  static const Curve snap     = Curves.easeOutCirc;
}

// ── Border Radius ─────────────────────────────────────────────────────────────
class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double round = 100;

  static BorderRadius get xs_r  => BorderRadius.circular(xs);
  static BorderRadius get sm_r  => BorderRadius.circular(sm);
  static BorderRadius get md_r  => BorderRadius.circular(md);
  static BorderRadius get lg_r  => BorderRadius.circular(lg);
  static BorderRadius get xl_r  => BorderRadius.circular(xl);
}

// ── Routes ────────────────────────────────────────────────────────────────────
class AppRoutes {
  static const String splash       = '/';
  static const String onboarding   = '/onboarding';
  static const String login        = '/login';
  static const String register     = '/register';
  static const String home         = '/home';
  static const String search       = '/search';
  static const String player       = '/player';
  static const String subscription = '/subscription';
  static const String profile      = '/profile';
  static const String downloads    = '/downloads';
  static const String localMedia   = '/local-media';
  static const String settings     = '/settings';
  static const String vault        = '/vault';
  static const String vaultLock    = '/vault-lock';
  static const String showDetail   = '/show-detail';
  static const String adminQueue   = '/admin-queue';
}

// ── Storage Keys ──────────────────────────────────────────────────────────────
class StorageKeys {
  static const String accessToken      = 'jm_access_token';
  static const String refreshToken     = 'jm_refresh_token';
  static const String userId           = 'jm_user_id';
  static const String deviceId         = 'jm_device_id';
  static const String onboardingSeen   = 'jm_onboarding_seen';
  static const String isGuest          = 'jm_is_guest';
  static const String cachedUserPhone  = 'jm_cached_phone';
  static const String cachedUserId     = 'jm_cached_user_id';
  static const String cachedUserPlan   = 'jm_cached_plan';
  static const String themeMode        = 'jm_theme_mode';
  static const String searchHistory    = 'jm_search_history';
}

// ── API Paths ─────────────────────────────────────────────────────────────────
class ApiPaths {
  static const String register          = '/api/auth/register';
  static const String login             = '/api/auth/login';
  static const String guest             = '/api/auth/guest';
  static const String refresh           = '/api/auth/refresh';
  static const String logout            = '/api/auth/logout';
  static const String me                = '/api/auth/me';
  static const String bindDevice        = '/api/auth/device';

  static const String catalogVersion    = '/api/catalog/version';
  static const String catalogSync       = '/api/catalog/sync';

  static const String plans             = '/api/subscription/plans';
  static const String subscriptionStatus= '/api/subscription/status';
  static const String tidSubmit         = '/api/subscription/tid/submit';
  static const String tidStatus         = '/api/subscription/tid/status';

  static const String historyBase       = '/api/history';
  static String saveHistory(String fileId) => '/api/history/$fileId';
  static String playUrl(String fileId)    => '/watch/api/play/$fileId';

  static const String adminQueue        = '/api/queue/status';
  static const String publicMethods      = '/api/payment-methods';
}
