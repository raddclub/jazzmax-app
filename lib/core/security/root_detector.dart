import 'package:flutter/services.dart';

/// Detects rooted devices and emulators via native platform channel.
/// Used at app startup to log a warning or restrict playback.
///
/// Note: We do NOT hard-block rooted devices — that would frustrate legitimate
/// power users. Instead, we FLAG it and disable screenshot security features
/// that are meaningless on root (since root can bypass FLAG_SECURE anyway).
class RootDetector {
  static const _channel = MethodChannel('com.jazzmax.app/root');

  static Future<bool> isRooted() async {
    try {
      return await _channel.invokeMethod<bool>('isRooted') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEmulator() async {
    try {
      return await _channel.invokeMethod<bool>('isEmulator') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns a combined risk assessment.
  static Future<SecurityRisk> assess() async {
    final rooted = await isRooted();
    final emulator = await isEmulator();
    if (rooted) return SecurityRisk.rooted;
    if (emulator) return SecurityRisk.emulator;
    return SecurityRisk.safe;
  }
}

enum SecurityRisk { safe, emulator, rooted }
