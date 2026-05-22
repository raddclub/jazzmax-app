import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../db/local_db.dart';

/// Manages video file downloads using Dio.
/// Files saved to app private storage — not accessible outside the app.
/// Tracks progress in local_db.dart downloads table.
class DownloadService {
  static final Dio _dio = Dio();

  /// Download a video file and save to private app storage.
  /// [onProgress] fires with value 0.0 → 1.0 as download progresses.
  static Future<void> downloadFile({
    required String fileId,
    required String titleText,
    required String streamUrl,
    String? posterUrl,
    required void Function(double progress) onProgress,
  }) async {
    final dir = await _getDownloadDir();
    final localPath = '${dir.path}/$fileId.mp4';

    // Insert record as 'downloading'
    await LocalDb.insertDownload(
      fileId: fileId,
      titleText: titleText,
      posterUrl: posterUrl,
      localPath: localPath,
    );

    try {
      await _dio.download(
        streamUrl,
        localPath,
        onReceiveProgress: (received, total) {
          final progress = total > 0 ? received / total : 0.0;
          onProgress(progress);
          LocalDb.updateDownloadProgress(fileId, progress);
        },
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      final file = File(localPath);
      final fileSize = await file.exists() ? await file.length() : 0;
      await LocalDb.updateDownloadStatus(
          fileId, 'completed', 1.0, fileSize);
      onProgress(1.0);
    } catch (e) {
      await LocalDb.updateDownloadStatus(fileId, 'failed', 0.0, 0);
      rethrow;
    }
  }

  /// Cancel and delete a download.
  static Future<void> deleteDownload(String fileId) async {
    await LocalDb.deleteDownload(fileId);
  }

  /// Check if a file is already downloaded.
  static Future<bool> isDownloaded(String fileId) async {
    final downloads = await LocalDb.getDownloads();
    final match = downloads.where((d) =>
        d['file_id'] == fileId && d['status'] == 'completed');
    if (match.isEmpty) return false;
    final path = match.first['local_path'] as String?;
    if (path == null) return false;
    return File(path).exists();
  }

  /// Get local file path for a downloaded file.
  static Future<String?> getLocalPath(String fileId) async {
    final downloads = await LocalDb.getDownloads();
    final match = downloads.where((d) =>
        d['file_id'] == fileId && d['status'] == 'completed');
    if (match.isEmpty) return null;
    return match.first['local_path'] as String?;
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
