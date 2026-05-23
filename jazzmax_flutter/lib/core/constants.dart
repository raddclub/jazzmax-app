import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'JazzMAX';
  static const String tagline = 'Pakistan ka entertainment, data-free';

  /// Runtime-mutable: updated by RemoteConfig.fetch() on every app start.
  /// Fallback = Oracle production server (permanent IP — never changes).
  /// To switch servers, edit jazzmax_config.json in GitHub — no APK rebuild needed.
  static String apiBaseUrl = 'http://92.4.95.252';

  static const String onboardingSeenKey = 'jm_onboarding_seen';

  static const Duration accessTokenValidity = Duration(minutes: 15);
  static const Duration refreshTokenValidity = Duration(days: 30);

  static const Duration catalogSyncInterval = Duration(hours: 6);
  static const String catalogDbName = 'jazzmax_catalog.db';
  static const int catalogDbVersion = 2;
}

class AppColors {
  static const Color primary = Color(0xFFE8002D);
  static const Color primaryDark = Color(0xFFB5001F);
  static const Color background = Color(0xFF08080E);
  static const Color surface = Color(0xFF0E0E1C);
  static const Color surfaceVariant = Color(0xFF151528);
  static const Color card = Color(0xFF1C1C35);
  static const Color textPrimary = Color(0xFFF2F2FF);
  static const Color textMuted = Color(0xFF6A6A90);
  static const Color divider = Color(0xFF1C1C35);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String player = '/player';
  static const String subscription = '/subscription';
  static const String profile = '/profile';
  static const String downloads = '/downloads';
}

class StorageKeys {
  static const String accessToken = 'jm_access_token';
  static const String refreshToken = 'jm_refresh_token';
  static const String userId = 'jm_user_id';
  static const String deviceId = 'jm_device_id';
  static const String onboardingSeen = 'jm_onboarding_seen';
  static const String isGuest = 'jm_is_guest';
}

class ApiPaths {
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String guest = '/api/auth/guest';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';
  static const String bindDevice = '/api/auth/device';

  static const String catalogVersion = '/api/catalog/version';
  static const String catalogSync = '/api/catalog/sync';

  static const String plans = '/api/subscription/plans';
  static const String subscriptionStatus = '/api/subscription/status';
  static const String tidSubmit = '/api/subscription/tid/submit';
  static const String tidStatus = '/api/subscription/tid/status';

  static const String historyBase = '/api/history';
  static String saveHistory(String fileId) => '/api/history/$fileId';

  static String playUrl(String fileId) => '/watch/api/play/$fileId';
}
