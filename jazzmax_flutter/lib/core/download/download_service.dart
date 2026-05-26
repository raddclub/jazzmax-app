import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../db/local_db.dart';
import '../services/jazzdrive_service.dart';
import '../debug/debug_logger.dart';

/// Manages video file downloads using Dio.
/// Files saved to app private storage — not accessible outside the app.
/// Tracks progress in local_db.dart downloads table.
class DownloadService {
  static final Dio _dio = Dio();

  /// Download a video file and save to private app storage.
  /// Resolves the stream URL on-device via JazzDrive (zero-rated) if possible,
  /// otherwise uses the [streamUrl] parameter as-is.
  /// [onProgress] fires with value 0.0 → 1.0 as download progresses.
  static Future<void> downloadFile({
    required String fileId,
    required String titleText,
    required String streamUrl,
    String? posterUrl,
    String? shareUrl,
    required void Function(double progress) onProgress,
  }) async {
    // Try to get a fresh zero-rated JazzDrive URL if share_url is known
    String resolvedUrl = streamUrl;
    if (shareUrl != null && shareUrl.isNotEmpty) {
      try {
        final link = await JazzDriveService.getStreamLink(fileId, shareUrl);
        resolvedUrl = link.streamUrl;
        DebugLogger.log('DOWNLOAD', 'Using JazzDrive URL for $fileId');
      } catch (e) {
        DebugLogger.logWarn('DOWNLOAD', 'JazzDrive link failed, using provided URL: $e');
      }
    } else {
      // Try fetching share_url from local DB (set during catalog sync)
      final dbShareUrl = await LocalDb.getShareUrl(fileId);
      if (dbShareUrl != null && dbShareUrl.isNotEmpty) {
        try {
          final link = await JazzDriveService.getStreamLink(fileId, dbShareUrl);
          resolvedUrl = link.streamUrl;
          DebugLogger.log('DOWNLOAD', 'Using DB JazzDrive URL for $fileId');
        } catch (e) {
          DebugLogger.logWarn('DOWNLOAD', 'DB JazzDrive link failed, using provided URL: $e');
        }
      }
    }
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
        resolvedUrl,
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
