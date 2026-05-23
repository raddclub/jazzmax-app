import '../constants.dart';
import 'api_client.dart';
import '../../models/user.dart';
import '../security/keystore.dart';
import '../security/device_id.dart';

class AuthApi {
  static final _client = ApiClient.instance;

  /// Continue as guest — returns a short-lived access token, no account needed.
  static Future<String> guestLogin() async {
    final response = await _client.post(ApiPaths.guest);
    final data = response.data as Map<String, dynamic>;
    return data['access_token'] as String;
  }

  /// Register a new account with phone + password.
  static Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
  }) async {
    final response = await _client.post(
      ApiPaths.register,
      data: {'phone': phone, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Login with phone + password. Returns access + refresh tokens.
  /// Also binds device ID automatically.
  static Future<LoginResult> login({
    required String phone,
    required String password,
  }) async {
    final deviceId = await DeviceIdentifier.getDeviceId();

    final response = await _client.post(
      ApiPaths.login,
      data: {
        'phone': phone,
        'password': password,
        'device_id': deviceId,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return LoginResult.fromJson(data);
  }

  /// Get the currently logged-in user's profile + subscription info.
  static Future<AppUser> getMe() async {
    final response = await _client.get(ApiPaths.me);
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  /// Logout — invalidates the refresh token on the server.
  static Future<void> logout() async {
    try {
      final refreshToken = await Keystore.getRefreshToken();
      if (refreshToken != null) {
        await _client.post(
          ApiPaths.logout,
          data: {'refresh_token': refreshToken},
        );
      }
    } catch (_) {
      // Ignore logout errors — we'll clear tokens locally regardless
    } finally {
      await Keystore.clearAll();
    }
  }

  /// Bind device to account (call after login on new devices).
  static Future<void> bindDevice() async {
    final deviceId = await DeviceIdentifier.getDeviceId();
    final deviceName = await DeviceIdentifier.getDeviceName();
    await _client.post(
      ApiPaths.bindDevice,
      data: {'device_id': deviceId, 'device_name': deviceName},
    );
  }
}

class LoginResult {
  final String accessToken;
  final String refreshToken;
  final int userId;
  final String phone;

  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.phone,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    return LoginResult(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      userId: json['user_id'] as int,
      phone: json['phone'] as String? ?? '',
    );
  }
}
