import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants.dart';

/// Stores and retrieves JWT tokens using Android Keystore (flutter_secure_storage).
/// Tokens are never stored in plain SharedPreferences — always encrypted at rest.
class Keystore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // ── Access Token ──────────────────────────────────────────────────────────

  static Future<String?> getAccessToken() =>
      _storage.read(key: StorageKeys.accessToken);

  static Future<void> saveAccessToken(String token) =>
      _storage.write(key: StorageKeys.accessToken, value: token);

  // ── Refresh Token ─────────────────────────────────────────────────────────

  static Future<String?> getRefreshToken() =>
      _storage.read(key: StorageKeys.refreshToken);

  static Future<void> saveRefreshToken(String token) =>
      _storage.write(key: StorageKeys.refreshToken, value: token);

  // ── User ID ───────────────────────────────────────────────────────────────

  static Future<String?> getUserId() =>
      _storage.read(key: StorageKeys.userId);

  static Future<void> saveUserId(String userId) =>
      _storage.write(key: StorageKeys.userId, value: userId);

  // ── Device ID ─────────────────────────────────────────────────────────────

  static Future<String?> getDeviceId() =>
      _storage.read(key: StorageKeys.deviceId);

  static Future<void> saveDeviceId(String deviceId) =>
      _storage.write(key: StorageKeys.deviceId, value: deviceId);

  // ── Save full token pair at once ──────────────────────────────────────────

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      saveAccessToken(accessToken),
      saveRefreshToken(refreshToken),
      saveUserId(userId),
    ]);
  }

  // ── Clear all on logout ───────────────────────────────────────────────────

  static Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: StorageKeys.accessToken),
      _storage.delete(key: StorageKeys.refreshToken),
      _storage.delete(key: StorageKeys.userId),
    ]);
  }

  static Future<bool> hasTokens() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
