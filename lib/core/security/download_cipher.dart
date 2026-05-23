import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Lightweight XOR cipher protecting downloaded video files.
///
/// Scrambles the first 128 bytes of each file — this destroys the container
/// magic bytes (MP4: `ftyp`, MKV: `\x1A\x45\xDF\xA3`, AVI: `RIFF`, etc.)
/// so the file cannot be identified or opened by any external video player,
/// even if an attacker extracts it from device storage.
///
/// This is NOT full-content encryption (that would require AES + key mgmt),
/// but it is more than sufficient to prevent casual piracy since:
/// 1. App-private storage is already sandboxed (other apps can't read it)
/// 2. The scrambled extension (.jmx) is unrecognised by all video players
/// 3. Only JazzMAX code knows how to decrypt/play these files
class DownloadCipher {
  // 16-byte rotating XOR key — derived from "JMX-SECURE-KEY!" ASCII
  static const List<int> _key = [
    0x4A, 0x4D, 0x58, 0x2D, // JMX-
    0x53, 0x45, 0x43, 0x55, // SECU
    0x52, 0x45, 0x2D, 0x4B, // RE-K
    0x45, 0x59, 0x21, 0x01, // EY!.
  ];

  static const String protectedExt = '.jmx';
  static const int _scrambleLen = 128;

  /// Protect a downloaded file: XOR first 128 bytes and save as .jmx.
  /// Returns the path to the protected file.
  static Future<String> protect(String sourcePath, String fileId) async {
    final dir = await getApplicationDocumentsDirectory();
    final vault = Directory(p.join(dir.path, 'jmx_vault'));
    await vault.create(recursive: true);

    // Use a hash of the fileId as filename so it can't be guessed
    final safeName = fileId.hashCode.abs().toRadixString(36);
    final destPath = p.join(vault.path, '$safeName$protectedExt');

    final bytes = await File(sourcePath).readAsBytes();
    final out = Uint8List.fromList(bytes);
    final len = out.length < _scrambleLen ? out.length : _scrambleLen;
    for (int i = 0; i < len; i++) {
      out[i] ^= _key[i % _key.length];
    }
    await File(destPath).writeAsBytes(out);
    return destPath;
  }

  /// Decrypt a .jmx file to a temporary path for playback.
  /// The caller MUST call [cleanTempFile] after playback finishes.
  static Future<String> decryptForPlayback(String jmxPath) async {
    final tmp = await getTemporaryDirectory();
    // Use timestamp for unique temp filename — no collision risk
    final tmpPath = p.join(
      tmp.path,
      'jmx_play_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );

    final bytes = await File(jmxPath).readAsBytes();
    final out = Uint8List.fromList(bytes);
    final len = out.length < _scrambleLen ? out.length : _scrambleLen;
    for (int i = 0; i < len; i++) {
      out[i] ^= _key[i % _key.length];
    }
    await File(tmpPath).writeAsBytes(out);
    return tmpPath;
  }

  /// Delete a temp playback file.
  static Future<void> cleanTempFile(String? tmpPath) async {
    if (tmpPath == null) return;
    try {
      final f = File(tmpPath);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Clean ALL temp JMX playback files (call on app start).
  static Future<void> cleanAllTemp() async {
    try {
      final tmp = await getTemporaryDirectory();
      await for (final entry in Directory(tmp.path).list()) {
        if (entry.path.contains('jmx_play_')) {
          await entry.delete();
        }
      }
    } catch (_) {}
  }

  static bool isProtected(String path) => path.endsWith(protectedExt);
}
