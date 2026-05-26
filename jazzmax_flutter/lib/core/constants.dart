import 'package:flutter/material.dart';

class AppConstants {
  static const String appName   = 'ZENO';
  static const String tagline   = 'Sab Dekho, Dil Khol Ke';
  static const String taglineEn = 'Stream Everything. Feel Everything.';
  static String apiBaseUrl = 'http://92.4.95.252';
  static const String onboardingSeenKey = 'zeno_onboarding_seen';
  static const Duration accessTokenValidity  = Duration(minutes: 15);
  static const Duration refreshTokenValidity = Duration(days: 90);
  static const Duration catalogSyncInterval  = Duration(hours: 6);
  static const String catalogDbName    = 'zeno_catalog.db';
  static const int    catalogDbVersion = 10;
  static const int    streamCacheTtlSeconds = 21600;
  static const String jazzDriveCloudBase   = 'https://cloud.jazzdrive.com.pk';
  static const String jazzDriveDbUpdateUrl = '';
  static const Duration streamLinkTtl      = Duration(hours: 6);
}

class AppColors {
  // ── Primary — ZENO Red ────────────────────────────────────────────────────
  static const Color primary      = Color(0xFFE8002D);
  static const Color primaryDark  = Color(0xFFB5001F);
  static const Color primaryGlow  = Color(0x40E8002D);
  static const Color primaryLight = Color(0xFFFF4D4D);

  // ── Accent — ZENO Orange ─────────────────────────────────────────────────
  static const Color accent     = Color(0xFFFF6B00);
  static const Color accentGlow = Color(0x40FF6B00);

  // ── Letter icon colors (semantic: Z=play, E=eye, N=bolt, O=people) ───────
  static const Color zColor = Color(0xFFE8002D);  // Z → play   (red)
  static const Color eColor = Color(0xFF2F8BFF);  // E → eye    (blue)
  static const Color nColor = Color(0xFFFFD000);  // N → bolt   (yellow)
  static const Color oColor = Color(0xFF22C55E);  // O → people (green)

  // ── Backgrounds — pure cinematic dark (no purple/blue tints) ─────────────
  static const Color background    = Color(0xFF0A0A0A);
  static const Color backgroundAlt = Color(0xFF141414);
  static const Color surface       = Color(0xFF1A1A1A);
  static const Color surfaceHigh   = Color(0xFF242424);
  static const Color card          = Color(0xFF1E1E1E);
  static const Color cardBorder    = Color(0xFF2A2A2A);

  // ── Glassmorphism ─────────────────────────────────────────────────────────
  static const Color glass       = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0x14FFFFFF);
  static const Color glassHigh   = Color(0x1AFFFFFF);

  // ── AMOLED ────────────────────────────────────────────────────────────────
  static const Color amoled        = Color(0xFF000000);
  static const Color amoledSurface = Color(0xFF0A0A0A);
  static const Color amoledCard    = Color(0xFF111111);

  // ── Light theme ───────────────────────────────────────────────────────────
  static const Color lightBg      = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard    = Color(0xFFF8F8F8);
  static const Color lightBorder  = Color(0xFFE0E0E0);

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary        = Color(0xFFFFFFFF);
  static const Color textSecondary      = Color(0xFFAAAAAA);
  static const Color textMuted          = Color(0xFF666666);
  static const Color textDisabled       = Color(0xFF404040);
  static const Color lightTextPrimary   = Color(0xFF0A0A0A);
  static const Color lightTextSecondary = Color(0xFF444444);
  static const Color lightTextMuted     = Color(0xFF888888);

  static const Color text   = textPrimary;
  static const Color border = glassBorder;

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success     = Color(0xFF22C55E);
  static const Color successGlow = Color(0x2222C55E);
  static const Color error       = Color(0xFFEF4444);
  static const Color errorGlow   = Color(0x22EF4444);
  static const Color warning     = Color(0xFFF59E0B);
  static const Color warningGlow = Color(0x22F59E0B);
  static const Color info        = Color(0xFF3B82F6);

  static const Color divider      = Color(0xFF1E1E1E);
  static const Color dividerLight = Color(0xFFE0E0E0);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE8002D), Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0A0A0A), Color(0xFF141414)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xFF0A0A0A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.3, 1.0],
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1E1E), Color(0xFF141414)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient zenoGradient = LinearGradient(
    colors: [Color(0xFFE8002D), Color(0xFFFF6B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ── Shadows ───────────────────────────────────────────────────────────────────
class AppShadows {
  static List<BoxShadow> get primary => [
    BoxShadow(color: AppColors.primary.withOpacity(0.35),
        blurRadius: 24, spreadRadius: -4, offset: const Offset(0, 8)),
  ];
  static List<BoxShadow> get card => [
    BoxShadow(color: Colors.black.withOpacity(0.4),
        blurRadius: 24, spreadRadius: -8, offset: const Offset(0, 12)),
    BoxShadow(color: AppColors.primary.withOpacity(0.06),
        blurRadius: 40, spreadRadius: -10),
  ];
  static List<BoxShadow> get soft => [
    BoxShadow(color: Colors.black.withOpacity(0.2),
        blurRadius: 16, spreadRadius: -4, offset: const Offset(0, 4)),
  ];
  static List<BoxShadow> get glow => [
    BoxShadow(color: AppColors.primary.withOpacity(0.45),
        blurRadius: 32, spreadRadius: -5),
  ];
  static List<BoxShadow> get elevated => [
    BoxShadow(color: Colors.black.withOpacity(0.6),
        blurRadius: 40, spreadRadius: -10, offset: const Offset(0, 20)),
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
  static const String accessToken     = 'zeno_access_token';
  static const String refreshToken    = 'zeno_refresh_token';
  static const String userId          = 'zeno_user_id';
  static const String deviceId        = 'zeno_device_id';
  static const String onboardingSeen  = 'zeno_onboarding_seen';
  static const String isGuest         = 'zeno_is_guest';
  static const String cachedUserPhone = 'zeno_cached_phone';
  static const String cachedUserId    = 'zeno_cached_user_id';
  static const String cachedUserPlan  = 'zeno_cached_plan';
  static const String themeMode       = 'zeno_theme_mode';
  static const String searchHistory   = 'zeno_search_history';
}

// ── API Paths ─────────────────────────────────────────────────────────────────
class ApiPaths {
  static const String register           = '/api/auth/register';
  static const String login              = '/api/auth/login';
  static const String guest              = '/api/auth/guest';
  static const String refresh            = '/api/auth/refresh';
  static const String logout             = '/api/auth/logout';
  static const String me                 = '/api/auth/me';
  static const String bindDevice         = '/api/auth/device';
  static const String catalogVersion     = '/api/catalog/version';
  static const String catalogSync        = '/api/catalog/sync';
  static const String plans              = '/api/subscription/plans';
  static const String subscriptionStatus = '/api/subscription/status';
  static const String tidSubmit          = '/api/subscription/tid/submit';
  static const String tidStatus          = '/api/subscription/tid/status';
  static const String historyBase        = '/api/history';
  static String saveHistory(String fileId) => '/api/history/$fileId';
  static String playUrl(String fileId)    => '/watch/api/play/$fileId';
  static const String adminQueue         = '/api/queue/status';
  static const String publicMethods      = '/api/payment-methods';
  static const String notifications      = '/api/notifications/';
  static const String notificationsRead  = '/api/notifications/read';
  static String notificationImage(int id) => '/api/notifications/image/$id';
}
