import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../db/local_db.dart';

class VaultService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _pinKey = 'vault_pin';
  static const _pinLenKey = 'vault_pin_length';
  static final _auth = LocalAuthentication();

  // ── PIN management ────────────────────────────────────────────────────────

  static Future<bool> isPinSet() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null && pin.isNotEmpty;
  }

  static Future<int> getPinLength() async {
    final len = await _storage.read(key: _pinLenKey);
    return int.tryParse(len ?? '6') ?? 6;
  }

  static Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _pinLenKey, value: pin.length.toString());
  }

  static Future<bool> verifyPin(String input) async {
    final stored = await _storage.read(key: _pinKey);
    return stored != null && stored == input;
  }

  static Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _pinLenKey);
  }

  // ── Biometric ─────────────────────────────────────────────────────────────

  static Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isSupported) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticateBiometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock your private vault',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ── Vault directory ───────────────────────────────────────────────────────

  static Future<Directory> getVaultDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'vault', 'files'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── File ID generation ────────────────────────────────────────────────────

  static String _newId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toString();
    final rand = Random.secure().nextInt(999999).toString().padLeft(6, '0');
    return '${ts}_$rand';
  }

  // ── Import file into vault ────────────────────────────────────────────────
  /// Moves [src] into the vault directory, renames it with an opaque ID
  /// so it cannot be found by gallery / file manager.
  /// Returns metadata map ready to insert into vault_items table.

  static Future<Map<String, dynamic>> importFile(File src) async {
    final vaultDir = await getVaultDir();
    final ext = p.extension(src.path);
    final id = _newId();
    final vaultPath = p.join(vaultDir.path, '$id$ext');

    // Copy first, then delete original (so original disappears from gallery)
    await src.copy(vaultPath);
    try {
      await src.delete();
    } catch (_) {}

    final fileSize = await File(vaultPath).length();
    final fileType = _detectType(ext);

    return {
      'id': id,
      'orig_name': p.basename(src.path),
      'vault_path': vaultPath,
      'file_type': fileType,
      'file_size': fileSize,
      'mime_type': _mimeType(ext),
    };
  }

  static Future<void> deleteVaultFile(String id, String vaultPath) async {
    try {
      await File(vaultPath).delete();
    } catch (_) {}
    await LocalDb.deleteVaultItem(id);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _detectType(String ext) {
    final e = ext.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'].contains(e)) {
      return 'image';
    }
    if (['.mp4', '.mkv', '.avi', '.mov', '.3gp', '.flv', '.webm'].contains(e)) {
      return 'video';
    }
    if (['.mp3', '.aac', '.wav', '.flac', '.ogg', '.m4a', '.opus'].contains(e)) {
      return 'audio';
    }
    if (['.pdf', '.doc', '.docx', '.txt', '.xlsx', '.xls', '.pptx', '.csv'].contains(e)) {
      return 'document';
    }
    return 'other';
  }

  static String _mimeType(String ext) {
    const map = {
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.webp': 'image/webp',
      '.mp4': 'video/mp4',
      '.mkv': 'video/x-matroska',
      '.avi': 'video/avi',
      '.mov': 'video/quicktime',
      '.mp3': 'audio/mpeg',
      '.aac': 'audio/aac',
      '.wav': 'audio/wav',
      '.flac': 'audio/flac',
      '.pdf': 'application/pdf',
      '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    };
    return map[ext.toLowerCase()] ?? 'application/octet-stream';
  }
}
