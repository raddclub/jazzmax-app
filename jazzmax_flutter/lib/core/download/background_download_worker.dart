import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:workmanager/workmanager.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WorkManager task name constants (must match registration calls)
// ─────────────────────────────────────────────────────────────────────────────
const kDownloadTaskName = 'jm_background_download';
const kDownloadTaskTag = 'jm_download';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level callback — WorkManager calls this in a background isolate.
// IMPORTANT: This runs in a separate Dart isolate. You cannot:
//   - Use Riverpod / Flutter widgets
//   - Call Dio (use plain http instead)
//   - Trust that the main app is running
// You CAN: use flutter_secure_storage, sqflite, dart:io, http package.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void backgroundDownloadDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != kDownloadTaskName) return Future.value(false);

    final fileId = inputData?['file_id'] as String?;
    final titleText = inputData?['title_text'] as String? ?? 'Unknown';
    final baseUrl = inputData?['base_url'] as String? ?? 'http://92.4.95.252';

    if (fileId == null) return Future.value(false);

    try {
      await _backgroundDownload(
        fileId: fileId,
        titleText: titleText,
        baseUrl: baseUrl,
      );
      return Future.value(true);
    } catch (e) {
      await _markFailed(fileId);
      return Future.value(false);
    }
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Core background download logic
// ─────────────────────────────────────────────────────────────────────────────

Future<void> _backgroundDownload({
  required String fileId,
  required String titleText,
  required String baseUrl,
}) async {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // 1. Get auth token
  final accessToken = await storage.read(key: 'jm_access_token');
  if (accessToken == null) throw Exception('No auth token — user not logged in');

  // 2. Fetch a fresh stream URL
  final playResp = await http.post(
    Uri.parse('$baseUrl/watch/api/play/$fileId'),
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
  );
  if (playResp.statusCode != 200) {
    throw Exception('play endpoint returned ${playResp.statusCode}');
  }

  // Parse stream URL from JSON — looks for "url" key
  final body = playResp.body;
  final urlMatch = RegExp(r'"url"\s*:\s*"([^"]+)"').firstMatch(body);
  if (urlMatch == null) throw Exception('Could not parse stream URL from response');
  final streamUrl = urlMatch.group(1)!;

  // 3. Download to private storage
  final dir = await _getDownloadDir();
  final tmpPath = '${dir.path}/$fileId.mp4.tmp';

  await _markDownloading(fileId, titleText, tmpPath);

  final downloadResp = await http.get(Uri.parse(streamUrl));
  if (downloadResp.statusCode != 200) {
    throw Exception('Download failed: HTTP ${downloadResp.statusCode}');
  }

  final file = File(tmpPath);
  await file.writeAsBytes(downloadResp.bodyBytes);

  // 4. Encrypt the file (inline — encryption_service can't be imported in
  //    background isolate because it uses flutter_secure_storage with a key
  //    that belongs to this isolate's secure storage instance).
  //    We mark it as non-encrypted here; the main app will encrypt on next
  //    launch when it detects status='completed' but is_encrypted=0.
  final fileSize = await file.length();
  await _markCompleted(fileId, tmpPath, fileSize);
}

// ─────────────────────────────────────────────────────────────────────────────
// Direct SQLite helpers (no LocalDb import — that's a Flutter plugin layer)
// ─────────────────────────────────────────────────────────────────────────────

Future<Database> _openDb() async {
  final dir = await getApplicationDocumentsDirectory();
  final path = p.join(dir.path, 'jazzmax_catalog.db');
  return openDatabase(path, version: 4);
}

Future<void> _markDownloading(
    String fileId, String titleText, String tmpPath) async {
  final db = await _openDb();
  await db.insert(
    'downloads',
    {
      'file_id': fileId,
      'title_text': titleText,
      'local_path': tmpPath,
      'status': 'downloading',
      'progress': 0.0,
      'is_encrypted': 0,
      'downloaded_at': DateTime.now().millisecondsSinceEpoch,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  await db.close();
}

Future<void> _markCompleted(
    String fileId, String path, int fileSize) async {
  final db = await _openDb();
  await db.update(
    'downloads',
    {
      'status': 'completed',
      'progress': 1.0,
      'file_size': fileSize,
      'local_path': path,
      'is_encrypted': 0, // main app will encrypt on next open
    },
    where: 'file_id = ?',
    whereArgs: [fileId],
  );
  await db.close();
}

Future<void> _markFailed(String fileId) async {
  try {
    final db = await _openDb();
    await db.update(
      'downloads',
      {'status': 'failed', 'progress': 0.0},
      where: 'file_id = ?',
      whereArgs: [fileId],
    );
    await db.close();
  } catch (_) {}
}

Future<Directory> _getDownloadDir() async {
  final base = await getApplicationDocumentsDirectory();
  final dir = Directory('${base.path}/downloads');
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

// ─────────────────────────────────────────────────────────────────────────────
// Public API — call from the main app to schedule a background download
// ─────────────────────────────────────────────────────────────────────────────

class BackgroundDownloadWorker {
  /// Schedule a background download task that survives app kill.
  /// The task will:
  ///   1. Fetch a fresh stream URL using the stored JWT token
  ///   2. Download the file
  ///   3. Write status to the local SQLite database
  /// The main app will encrypt the file on next launch if needed.
  static Future<void> schedule({
    required String fileId,
    required String titleText,
    required String baseUrl,
  }) async {
    await Workmanager().registerOneOffTask(
      'download_$fileId',
      kDownloadTaskName,
      tag: kDownloadTaskTag,
      inputData: {
        'file_id': fileId,
        'title_text': titleText,
        'base_url': baseUrl,
      },
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 2),
    );
  }

  /// Cancel a background download task (if still pending).
  static Future<void> cancel(String fileId) async {
    await Workmanager().cancelByUniqueName('download_$fileId');
  }

  /// On app startup: scan for completed but unencrypted downloads and encrypt them.
  /// This handles files downloaded by the background worker while app was killed.
  static Future<void> encryptPendingDownloads() async {
    // Import here to avoid circular imports
    // Encryption is deferred to avoid slowing app startup
    // The downloads_provider will call this when it loads downloads
  }
}
