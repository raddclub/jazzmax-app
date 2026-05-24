import 'package:device_info_plus/device_info_plus.dart';
import 'keystore.dart';

/// Gets a stable unique device identifier for account binding.
/// Uses Android's ANDROID_ID — unique per device + app install.
/// Cached in secure storage so it's the same across app restarts.
class DeviceIdentifier {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getDeviceId() async {
    // Return cached value if available
    final cached = await Keystore.getDeviceId();
    if (cached != null && cached.isNotEmpty) return cached;

    // Generate from Android device info
    final id = await _generateId();
    await Keystore.saveDeviceId(id);
    return id;
  }

  static Future<String> _generateId() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      final id = androidInfo.id; // ANDROID_ID — stable per device
      if (id.isNotEmpty) return 'android_$id';
    } catch (_) {}

    // Fallback: generate a random ID (persisted in secure storage)
    final fallback = 'device_${DateTime.now().millisecondsSinceEpoch}';
    return fallback;
  }

  static Future<String> getDeviceName() async {
    try {
      final androidInfo = await _deviceInfo.androidInfo;
      final brand = androidInfo.brand.trim();
      final model = androidInfo.model.trim();
      // Some manufacturers (Infinix, Samsung, etc.) include brand in the model name already.
      // e.g. brand="Infinix" model="Infinix X680F" → avoid "Infinix Infinix X680F"
      if (model.toLowerCase().startsWith(brand.toLowerCase())) {
        return model;
      }
      return '$brand $model'.trim();
    } catch (_) {
      return 'Android Device';
    }
  }
}
