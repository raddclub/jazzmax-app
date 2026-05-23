import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../db/local_db.dart';
import '../security/encryption_service.dart';

/// Manages video file downloads using Dio.
/// Files saved to app private storage — not accessible outside the app.
/// After download completes, the file is AES-256 encrypted and the
/// original plaintext is deleted.
class DownloadService {
  static final Dio _dio = Dio();

  /// Download a video file, encrypt it, and save to private app storage.
  /// [onProgress] fires with value 0.0 → 1.0 as download progresses.
  /// Note: progress goes 0.0 → 0.9 during download, 0.9 → 1.0 during encryption.
  static Future<void> downloadFile({
    required String fileId,
    required String titleText,
    required String streamUrl,
    String? posterUrl,
    required void Function(double progress) onProgress,
  }) async {
    final dir = await _getDownloadDir();
    // Download to a temporary plaintext file first
    final tmpPath = '${dir.path}/$fileId.mp4.tmp';

    // Insert record as 'downloading'
    await LocalDb.insertDownload(
      fileId: fileId,
      titleText: titleText,
      posterUrl: posterUrl,
      localPath: tmpPath, // will be updated after encryption
    );

    try {
      // ── Phase 1: Download ────────────────────────────────────────────────
      await _dio.download(
        streamUrl,
        tmpPath,
        onReceiveProgress: (received, total) {
          // Map download progress to 0.0 → 0.9 range
          final p = total > 0 ? (received / total) * 0.9 : 0.0;
          onProgress(p);
          LocalDb.updateDownloadProgress(fileId, p);
        },
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      // ── Phase 2: Encrypt (0.9 → 1.0) ────────────────────────────────────
      onProgress(0.9);
      LocalDb.updateDownloadProgress(fileId, 0.9);

      final encPath = await EncryptionService.encryptFile(tmpPath);
      // tmpPath is deleted by encryptFile; encPath is the new location

      final encFile = File(encPath);
      final fileSize = await encFile.exists() ? await encFile.length() : 0;

      // Update DB with final encrypted path
      await LocalDb.finalizeDownload(fileId, encPath, fileSize);
      onProgress(1.0);
    } catch (e) {
      // Clean up temp file if encryption or download failed
      try { await File(tmpPath).delete(); } catch (_) {}
      await LocalDb.updateDownloadStatus(fileId, 'failed', 0.0, 0);
      rethrow;
    }
  }

  /// Cancel and delete a download (removes DB record + local file).
  static Future<void> deleteDownload(String fileId) async {
    await LocalDb.deleteDownload(fileId);
  }

  /// Check if a file is already downloaded (completed + file exists).
  static Future<bool> isDownloaded(String fileId) async {
    final downloads = await LocalDb.getDownloads();
    final match = downloads.where(
        (d) => d['file_id'] == fileId && d['status'] == 'completed');
    if (match.isEmpty) return false;
    final path = match.first['local_path'] as String?;
    if (path == null) return false;
    return File(path).exists();
  }

  /// Get local encrypted file path for a downloaded file.
  static Future<String?> getLocalPath(String fileId) async {
    final downloads = await LocalDb.getDownloads();
    final match = downloads.where(
        (d) => d['file_id'] == fileId && d['status'] == 'completed');
    if (match.isEmpty) return null;
    return match.first['local_path'] as String?;
  }

  /// Whether the download record has the file encrypted.
  static Future<bool> isEncrypted(String fileId) async {
    final downloads = await LocalDb.getDownloads();
    final match = downloads.where((d) => d['file_id'] == fileId);
    if (match.isEmpty) return false;
    return (match.first['is_encrypted'] as int? ?? 0) == 1;
  }

  static Future<Directory> _getDownloadDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
