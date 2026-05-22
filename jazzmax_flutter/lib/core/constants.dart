import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'JazzMAX';
  static const String tagline = 'Pakistan ka entertainment, data-free';

  // API Base URLs
  // Android emulator → 10.0.2.2 maps to host machine's localhost
  // Real device on same WiFi → use your PC's LAN IP e.g. http://192.168.1.x:8000
  static const String apiBaseUrl = 'http://10.0.2.2:8000';

  // Token lifetimes
  static const Duration accessTokenValidity = Duration(minutes: 15);
  static const Duration refreshTokenValidity = Duration(days: 30);

  // Catalog sync
  static const Duration catalogSyncInterval = Duration(hours: 6);
  static const String catalogDbName = 'jazzmax_catalog.db';
  static const int catalogDbVersion = 1;
}

class AppColors {
  static const Color primary = Color(0xFFE8002D);        // Jazz Pakistan official red
  static const Color primaryDark = Color(0xFFB5001F);    // Darker red for pressed states
  static const Color background = Color(0xFF08080E);     // Obsidian dark
  static const Color surface = Color(0xFF0E0E1C);        // Dark surface
  static const Color surfaceVariant = Color(0xFF151528); // Slightly lighter
  static const Color card = Color(0xFF1C1C35);           // Card background
  static const Color textPrimary = Color(0xFFF2F2FF);    // Near white
  static const Color textMuted = Color(0xFF6A6A90);      // Muted/secondary text
  static const Color divider = Color(0xFF1C1C35);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String player = '/player';
  static const String subscription = '/subscription';
  static const String profile = '/profile';
}

class StorageKeys {
  static const String accessToken = 'jm_access_token';
  static const String refreshToken = 'jm_refresh_token';
  static const String userId = 'jm_user_id';
  static const String deviceId = 'jm_device_id';
}

class ApiPaths {
  // Auth
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String refresh = '/api/auth/refresh';
  static const String logout = '/api/auth/logout';
  static const String me = '/api/auth/me';
  static const String bindDevice = '/api/auth/device';

  // Catalog
  static const String catalogVersion = '/api/catalog/version';
  static const String catalogSync = '/api/catalog/sync';

  // Subscription
  static const String plans = '/api/subscription/plans';
  static const String subscriptionStatus = '/api/subscription/status';
  static const String tidSubmit = '/api/subscription/tid/submit';
  static const String tidStatus = '/api/subscription/tid/status';

  // Watch / Stream
  static String playUrl(String fileId) => '/watch/api/play/$fileId';
}
