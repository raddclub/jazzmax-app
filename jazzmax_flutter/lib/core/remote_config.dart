import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'api/api_client.dart';

/// Fetches server URL from a GitHub-hosted JSON file.
/// To switch servers (Replit → Oracle, etc.) just update the JSON file —
/// no APK rebuild required.
///
/// Config file: https://raw.githubusercontent.com/raddclub/jazzmax-app/main/raddflix_config.json
class RemoteConfig {
  static const String _configUrl =
      'https://raw.githubusercontent.com/raddclub/jazzmax-app/main/raddflix_config.json';
  static const String _prefsKey = 'jm_remote_config';

  static Future<void> fetch() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try fetching fresh from GitHub raw
    try {
      final dio = Dio();
      final res = await dio.get<dynamic>(
        _configUrl,
        options: Options(
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String
            ? jsonDecode(res.data as String) as Map<String, dynamic>
            : res.data as Map<String, dynamic>;
        final url = (data['api_base_url'] as String?)?.trim();
        if (url != null && url.isNotEmpty) {
          AppConstants.apiBaseUrl = url;
          await prefs.setString(_prefsKey, jsonEncode(data));
          ApiClient.updateBaseUrl(url);
          return;
        }
      }
    } catch (_) {}

    // 2. Fall back to last-cached config
    final cached = prefs.getString(_prefsKey);
    if (cached != null) {
      try {
        final data = jsonDecode(cached) as Map<String, dynamic>;
        final url = (data['api_base_url'] as String?)?.trim();
        if (url != null && url.isNotEmpty) {
          AppConstants.apiBaseUrl = url;
          ApiClient.updateBaseUrl(url);
          return;
        }
      } catch (_) {}
    }

    // 3. Use whatever hardcoded fallback is in AppConstants
    ApiClient.updateBaseUrl(AppConstants.apiBaseUrl);
  }
}
