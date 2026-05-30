import 'dart:convert';
import 'package:dio/dio.dart';
import '../api/catalog_api.dart';
import '../constants.dart';
import '../debug/debug_logger.dart';
import '../services/usage_service.dart';
import 'local_db.dart';
import '../../models/catalog_item.dart';

/// Handles syncing the catalog from the server into the local SQLite database.
///
/// Sync priority:
///   1. Oracle server (http://92.4.95.252) — when internet is available
///   2. JazzDrive delta.json — zero-rated fallback when no internet bundle
///
/// Delta format (JazzDrive path): metadata only — id, title, year, description,
/// poster_url, genres, is_free. NO file_id, NO share_url (security).
/// Uses [LocalDb.mergeDeltaTitle] which preserves share_url from prior Oracle syncs.
///
/// On first run: full sync (downloads everything).
/// On subsequent runs: delta sync (only new/changed items since last sync).
class SyncService {
  static Future<SyncResult> sync() async {
    // Try Oracle server first
    try {
      final result = await _syncFromOracle();
      return result;
    } catch (e) {
      DebugLogger.logWarn('SYNC', 'Oracle sync failed: $e — trying JazzDrive fallback');
    }

    // Fallback: JazzDrive zero-rated delta sync (works without internet bundle)
    if (AppConstants.jazzDriveDeltaUrl.isNotEmpty) {
      try {
        final result = await _syncFromJazzDriveDelta();
        return result;
      } catch (e) {
        DebugLogger.logError('SYNC', 'JazzDrive delta fallback also failed', e);
      }
    }

    return const SyncResult(
      success: false,
      itemsSynced: 0,
      message: 'Sync failed: no internet and no JazzDrive delta fallback configured',
      isUpToDate: false,
    );
  }

  // ── Oracle server sync ────────────────────────────────────────────────────

  static Future<SyncResult> _syncFromOracle() async {
    // 6.9 — fire quota refresh in background whenever Oracle is reachable.
    // Ensures sub_expires_at is cached even if the user has never flushed
    // usage bytes (e.g. downloaded content but never streamed anything).
    UsageService.fetchQuota().ignore();

    final lastSyncTs = await LocalDb.getLastSyncTimestamp();
    final serverVersion = await CatalogApi.getVersion();
    final localVersion = await LocalDb.getLastSyncVersion();

    if (localVersion >= serverVersion.version && lastSyncTs > 0) {
      return const SyncResult(
        success: true,
        itemsSynced: 0,
        message: 'Already up to date',
        isUpToDate: true,
      );
    }

    List<CatalogItem> items;
    if (lastSyncTs == 0) {
      items = await CatalogApi.syncFull();
    } else {
      items = await CatalogApi.syncDelta(lastSyncTs);
    }

    await _persistItems(items);

    final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await LocalDb.setLastSyncVersion(serverVersion.version);
    await LocalDb.setLastSyncTimestamp(nowTs);

    DebugLogger.log('SYNC', 'Oracle sync complete: ${items.length} item(s)');
    return SyncResult(
      success: true,
      itemsSynced: items.length,
      message: 'Synced ${items.length} item(s) from server',
      isUpToDate: false,
    );
  }

  // ── JazzDrive zero-rated delta sync ──────────────────────────────────────

  /// Fetches delta.json from JazzDrive (zero-rated) and merges it into the
  /// local catalog. Uses [LocalDb.mergeDeltaTitle] to preserve any share_url /
  /// poster_path values written by a previous Oracle sync — critical because
  /// the delta is metadata-only and does not carry streaming credentials.
  static Future<SyncResult> _syncFromJazzDriveDelta() async {
    DebugLogger.log('SYNC', 'Attempting JazzDrive delta.json sync (zero-rated)');

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final resp = await dio.get<dynamic>(AppConstants.jazzDriveDeltaUrl);
    if (resp.statusCode != 200 || resp.data == null) {
      throw Exception('JazzDrive delta sync: HTTP ${resp.statusCode}');
    }

    final raw = resp.data is String
        ? json.decode(resp.data as String) as Map<String, dynamic>
        : resp.data as Map<String, dynamic>;

    final remoteVersion = raw['version'] as int? ?? 0;
    final localVersion = await LocalDb.getLastSyncVersion();

    if (localVersion >= remoteVersion && localVersion > 0) {
      DebugLogger.log('SYNC', 'JazzDrive delta: already up to date (v$localVersion)');
      return const SyncResult(
        success: true,
        itemsSynced: 0,
        message: 'Already up to date (JazzDrive delta)',
        isUpToDate: true,
      );
    }

    final titlesRaw = raw['titles'] as List<dynamic>? ?? [];
    int merged = 0;

    for (final t in titlesRaw) {
      final row = t as Map<String, dynamic>;
      await LocalDb.mergeDeltaTitle({
        'id':          row['id'],
        'title':       row['title'] ?? '',
        'year':        row['year'],
        'media_type':  row['media_type'] ?? 'movie',
        'description': row['description'] ?? '',
        'rating':      (row['rating'] as num?)?.toDouble() ?? 0.0,
        'genres':      row['genres'] is List
            ? json.encode(row['genres'])
            : (row['genres'] as String? ?? '[]'),
        'poster_url':  row['poster_url'] ?? '',
        'is_free':     (row['is_free'] == true || row['is_free'] == 1) ? 1 : 0,
        'db_version':  row['db_version'] ?? 0,
        'language':    row['language'] ?? '',
        'status':      row['status'] ?? 'released',
        'is_ongoing':  (row['is_ongoing'] == true || row['is_ongoing'] == 1) ? 1 : 0,
      });
      merged++;
    }

    final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await LocalDb.setLastSyncVersion(remoteVersion);
    await LocalDb.setLastSyncTimestamp(nowTs);

    DebugLogger.log('SYNC', 'JazzDrive delta sync complete: $merged title(s) merged');
    return SyncResult(
      success: true,
      itemsSynced: merged,
      message: 'Synced $merged title(s) via JazzDrive delta (zero-rated, metadata only)',
      isUpToDate: false,
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  /// Full persist — used by Oracle sync. Replaces the full row including
  /// share_url and file_id which come from the trusted Oracle server.
  static Future<void> _persistItems(List<CatalogItem> items) async {
    for (final item in items) {
      await LocalDb.upsertTitle(item);
      for (final ep in item.episodes) {
        await LocalDb.upsertEpisode({
          'id':        ep['id'],
          'title_id':  item.id,
          'file_id':   ep['file_id']?.toString(),
          'season':    ep['season'],
          'episode':   ep['episode'],
          'label':     ep['label'],
          'quality':   ep['quality'],
          'is_free':   (ep['is_free'] == true || ep['is_free'] == 1) ? 1 : 0,
          'share_url': ep['share_url'] as String?,
        });
      }
    }
  }
}

class SyncResult {
  final bool success;
  final int itemsSynced;
  final String message;
  final bool isUpToDate;

  const SyncResult({
    required this.success,
    required this.itemsSynced,
    required this.message,
    required this.isUpToDate,
  });
}
