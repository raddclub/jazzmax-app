import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// AES-256-CBC file encryption for downloaded videos.
///
/// File format (.enc):
///   [4 bytes] magic "JMXE"
///   [8 bytes] original file size (big-endian uint64)
///   For each 4 MB chunk of plaintext:
///     [16 bytes] random IV for this chunk
///     [4 bytes]  original chunk length in bytes (big-endian uint32)
///     [N bytes]  CBC-encrypted data (PKCS7-padded to 16-byte boundary)
///
/// Key: AES-256 random key, generated once per device, stored in Android Keystore
/// via flutter_secure_storage. Never leaves the device.
class EncryptionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _keyAlias = 'jm_download_aes_key_v1';
  static const _chunkSize = 4 * 1024 * 1024; // 4 MB
  static const _magic = [0x4A, 0x4D, 0x58, 0x45]; // "JMXE"

  static enc.Key? _cachedKey;

  // ── Key management ─────────────────────────────────────────────────────────

  static Future<enc.Key> _getKey() async {
    if (_cachedKey != null) return _cachedKey!;
    String? b64 = await _storage.read(key: _keyAlias);
    if (b64 == null) {
      final rng = Random.secure();
      final bytes = Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
      b64 = enc.Key(bytes).base64;
      await _storage.write(key: _keyAlias, value: b64);
    }
    _cachedKey = enc.Key.fromBase64(b64);
    return _cachedKey!;
  }

  // ── Encryption ─────────────────────────────────────────────────────────────

  /// Encrypt [inputPath] with AES-256.
  /// Returns the new path (same path + ".enc"). Deletes the original.
  static Future<String> encryptFile(String inputPath) async {
    final key = await _getKey();
    final inputFile = File(inputPath);
    final originalSize = await inputFile.length();
    final outputPath = '$inputPath.enc';
    final outSink = File(outputPath).openWrite();

    try {
      // Write header
      outSink.add(Uint8List.fromList(_magic));
      outSink.add(_uint64ToBytes(originalSize));

      final rng = Random.secure();
      final inputStream = inputFile.openRead();
      final buf = <int>[];

      await for (final chunk in inputStream) {
        buf.addAll(chunk);
        while (buf.length >= _chunkSize) {
          final slice = Uint8List.fromList(buf.sublist(0, _chunkSize));
          buf.removeRange(0, _chunkSize);
          _writeEncryptedChunk(outSink, key, rng, slice);
        }
      }

      // Write final partial chunk
      if (buf.isNotEmpty) {
        _writeEncryptedChunk(outSink, key, rng, Uint8List.fromList(buf));
      }

      await outSink.flush();
    } finally {
      await outSink.close();
    }

    await inputFile.delete();
    return outputPath;
  }

  static void _writeEncryptedChunk(
    IOSink sink,
    enc.Key key,
    Random rng,
    Uint8List plaintext,
  ) {
    final iv = enc.IV(Uint8List.fromList(List.generate(16, (_) => rng.nextInt(256))));
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plaintext, iv: iv);
    sink.add(iv.bytes);
    sink.add(_uint32ToBytes(plaintext.length));
    sink.add(encrypted.bytes);
  }

  // ── Decryption ─────────────────────────────────────────────────────────────

  /// Decrypt [encPath] to a temporary file. Returns the temp file path.
  /// IMPORTANT: caller must delete the temp file after use.
  static Future<String> decryptToTemp(String encPath) async {
    final key = await _getKey();
    final tmpDir = await getTemporaryDirectory();
    final tmpPath = '${tmpDir.path}/jm_play_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final outSink = File(tmpPath).openWrite();

    try {
      final allBytes = await File(encPath).readAsBytes();
      int pos = 0;

      // Validate magic
      if (allBytes.length < 12) throw Exception('Not a valid JazzMAX encrypted file');
      final magic = allBytes.sublist(0, 4);
      if (!_listEquals(magic, _magic)) throw Exception('Invalid encrypted file magic');
      pos = 4;

      // Read original size (unused but validated)
      // ignore: unused_local_variable
      final originalSize = _bytesToUint64(allBytes.sublist(pos, pos + 8));
      pos += 8;

      // Decrypt chunks
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      while (pos < allBytes.length) {
        if (pos + 16 + 4 > allBytes.length) break;

        final iv = enc.IV(allBytes.sublist(pos, pos + 16));
        pos += 16;

        final chunkOrigLen = _bytesToUint32(allBytes.sublist(pos, pos + 4));
        pos += 4;

        // CBC padded size
        final paddedLen = _cbcPaddedSize(chunkOrigLen);
        if (pos + paddedLen > allBytes.length) break;

        final encData = enc.Encrypted(allBytes.sublist(pos, pos + paddedLen));
        pos += paddedLen;

        final decrypted = encrypter.decryptBytes(encData, iv: iv);
        // Only write the original (un-padded) bytes
        outSink.add(Uint8List.fromList(decrypted.sublist(0, chunkOrigLen)));
      }

      await outSink.flush();
    } catch (e) {
      await outSink.close();
      try { await File(tmpPath).delete(); } catch (_) {}
      rethrow;
    }

    await outSink.close();
    return tmpPath;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static int _cbcPaddedSize(int len) {
    final pad = 16 - (len % 16);
    return len + pad;
  }

  static Uint8List _uint64ToBytes(int value) {
    final b = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      b[i] = value & 0xFF;
      value >>= 8;
    }
    return b;
  }

  static Uint8List _uint32ToBytes(int value) {
    final b = Uint8List(4);
    b[0] = (value >> 24) & 0xFF;
    b[1] = (value >> 16) & 0xFF;
    b[2] = (value >> 8) & 0xFF;
    b[3] = value & 0xFF;
    return b;
  }

  static int _bytesToUint64(List<int> b) {
    int v = 0;
    for (int i = 0; i < 8; i++) {
      v = (v << 8) | (b[i] & 0xFF);
    }
    return v;
  }

  static int _bytesToUint32(List<int> b) {
    return ((b[0] & 0xFF) << 24) |
        ((b[1] & 0xFF) << 16) |
        ((b[2] & 0xFF) << 8) |
        (b[3] & 0xFF);
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
