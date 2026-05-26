import 'dart:convert';
import 'package:dio/dio.dart';
import '../api/catalog_api.dart';
import '../constants.dart';
import '../debug/debug_logger.dart';
import 'local_db.dart';
import '../../models/catalog_item.dart';

/// Handles syncing the catalog from the server into the local SQLite database.
///
/// Sync priority:
///   1. Oracle server (http://92.4.95.252) — when internet is available
///   2. JazzDrive db_update.json — zero-rated fallback when no internet bundle
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

    // Fallback: JazzDrive zero-rated sync (works without internet bundle)
    if (AppConstants.jazzDriveDbUpdateUrl.isNotEmpty) {
      try {
        final result = await _syncFromJazzDrive();
        return result;
      } catch (e) {
        DebugLogger.logError('SYNC', 'JazzDrive fallback sync also failed', e);
      }
    }

    return const SyncResult(
      success: false,
      itemsSynced: 0,
      message: 'Sync failed: no internet and no JazzDrive fallback configured',
      isUpToDate: false,
    );
  }

  // ── Oracle server sync ────────────────────────────────────────────────────

  static Future<SyncResult> _syncFromOracle() async {
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

  // ── JazzDrive zero-rated fallback sync ───────────────────────────────────

  static Future<SyncResult> _syncFromJazzDrive() async {
    DebugLogger.log('SYNC', 'Attempting JazzDrive db_update.json sync (zero-rated)');

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final resp = await dio.get<dynamic>(AppConstants.jazzDriveDbUpdateUrl);
    if (resp.statusCode != 200 || resp.data == null) {
      throw Exception('JazzDrive sync: HTTP ${resp.statusCode}');
    }

    final raw = resp.data is String
        ? json.decode(resp.data as String) as Map<String, dynamic>
        : resp.data as Map<String, dynamic>;

    final remoteVersion = raw['version'] as int? ?? 0;
    final localVersion = await LocalDb.getLastSyncVersion();

    if (localVersion >= remoteVersion && localVersion > 0) {
      DebugLogger.log('SYNC', 'JazzDrive: already up to date (v$localVersion)');
      return const SyncResult(
        success: true,
        itemsSynced: 0,
        message: 'Already up to date (JazzDrive)',
        isUpToDate: true,
      );
    }

    final titlesRaw = raw['titles'] as List<dynamic>? ?? [];
    final episodesRaw = raw['episodes'] as List<dynamic>? ?? [];

    final items = titlesRaw
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // Attach episodes to their parent items
    final epsByTitle = <int, List<Map<String, dynamic>>>{};
    for (final ep in episodesRaw) {
      final m = ep as Map<String, dynamic>;
      final tid = m['title_id'] as int? ?? 0;
      epsByTitle.putIfAbsent(tid, () => []).add(m);
    }

    final itemsWithEps = items.map((item) {
      final eps = epsByTitle[item.id] ?? [];
      return item.copyWithEpisodes(eps);
    }).toList();

    await _persistItems(itemsWithEps);

    final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await LocalDb.setLastSyncVersion(remoteVersion);
    await LocalDb.setLastSyncTimestamp(nowTs);

    DebugLogger.log('SYNC', 'JazzDrive sync complete: ${items.length} item(s)');
    return SyncResult(
      success: true,
      itemsSynced: items.length,
      message: 'Synced ${items.length} item(s) via JazzDrive (zero-rated)',
      isUpToDate: false,
    );
  }

  // ── Persistence ────────────────────────────────────────────────────────────

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
