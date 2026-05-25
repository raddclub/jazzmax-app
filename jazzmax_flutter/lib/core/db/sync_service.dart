import '../api/catalog_api.dart';
import 'local_db.dart';
import '../../models/catalog_item.dart';
import '../debug/debug_logger.dart';

/// Handles syncing the catalog from the server into the local SQLite database.
/// On first run: full sync (downloads everything).
/// On subsequent runs: delta sync (only new/changed items since last sync).
class SyncService {
  static Future<SyncResult> sync() async {
    try {
      final lastSyncTs = await LocalDb.getLastSyncTimestamp();
      final localVersion = await LocalDb.getLastSyncVersion();

      DebugLogger.logSync('START',
          'lastSyncTs=$lastSyncTs  localVersion=$localVersion');

      CatalogVersion serverVersion;
      try {
        serverVersion = await CatalogApi.getVersion();
        DebugLogger.logSync('VERSION',
            'serverVersion=${serverVersion.version}  serverCount=${serverVersion.count}');
      } catch (e, s) {
        DebugLogger.logError('SYNC', 'getVersion() API call failed', e, s);
        return SyncResult(
          success: false,
          itemsSynced: 0,
          message: 'Sync failed: version check error: $e',
          isUpToDate: false,
        );
      }

      // Check if sync is needed
      if (localVersion >= serverVersion.version && lastSyncTs > 0) {
        DebugLogger.logSync('SKIP', 'Already up to date (local=$localVersion >= server=${serverVersion.version})');
        return SyncResult(
          success: true,
          itemsSynced: 0,
          message: 'Already up to date',
          isUpToDate: true,
        );
      }

      // Choose full or delta sync
      List<CatalogItem> items;
      if (lastSyncTs == 0) {
        DebugLogger.logSync('FULL', 'First run — performing full sync');
        try {
          items = await CatalogApi.syncFull();
          DebugLogger.logSync('FULL_RECV',
              'Received ${items.length} items from server');
          // Log breakdown
          final movies = items.where((i) => i.mediaType == 'movie').length;
          final shows = items.where((i) => i.mediaType == 'show').length;
          final other = items.length - movies - shows;
          DebugLogger.logSync('FULL_DETAIL',
              'movies=$movies  shows=$shows  other=$other');
          if (items.isEmpty) {
            DebugLogger.logWarn('SYNC', 'Server returned 0 items on full sync!');
          }
          // Log a sample of media_types
          final types = items.map((i) => i.mediaType).toSet();
          DebugLogger.logSync('FULL_TYPES', 'media_types seen: $types');
        } catch (e, s) {
          DebugLogger.logError('SYNC', 'syncFull() API call failed', e, s);
          return SyncResult(
            success: false,
            itemsSynced: 0,
            message: 'Sync failed: full sync error: $e',
            isUpToDate: false,
          );
        }
      } else {
        DebugLogger.logSync('DELTA', 'Delta sync since ts=$lastSyncTs');
        try {
          items = await CatalogApi.syncDelta(lastSyncTs);
          DebugLogger.logSync('DELTA_RECV',
              'Received ${items.length} changed items');
        } catch (e, s) {
          DebugLogger.logError('SYNC', 'syncDelta() API call failed', e, s);
          return SyncResult(
            success: false,
            itemsSynced: 0,
            message: 'Sync failed: delta sync error: $e',
            isUpToDate: false,
          );
        }
      }

      // Write to local DB
      DebugLogger.logSync('DB_WRITE', 'Writing ${items.length} items to SQLite...');
      int written = 0;
      int epWritten = 0;
      for (final item in items) {
        try {
          await LocalDb.upsertTitle(item);
          written++;
        } catch (e) {
          DebugLogger.logError('SYNC', 'upsertTitle failed for id=${item.id} title=${item.title}', e);
        }

        for (final ep in item.episodes) {
          try {
            await LocalDb.upsertEpisode({
              'id': ep['id'],
              'title_id': item.id,
              'file_id': ep['file_id']?.toString(),
              'season': ep['season'],
              'episode': ep['episode'],
              'label': ep['label'],
              'quality': ep['quality'],
              'is_free': (ep['is_free'] == true || ep['is_free'] == 1) ? 1 : 0,
            });
            epWritten++;
          } catch (e) {
            DebugLogger.logError('SYNC', 'upsertEpisode failed for title=${item.id} ep=${ep['id']}', e);
          }
        }
      }
      DebugLogger.logSync('DB_DONE', 'Wrote $written titles, $epWritten episodes');

      // Update sync metadata
      final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await LocalDb.setLastSyncVersion(serverVersion.version);
      await LocalDb.setLastSyncTimestamp(nowTs);
      DebugLogger.logSync('META', 'Updated sync_meta: version=${serverVersion.version}  ts=$nowTs');

      DebugLogger.logSync('SUCCESS', 'Sync complete — ${items.length} item(s) synced');
      return SyncResult(
        success: true,
        itemsSynced: items.length,
        message: 'Synced ${items.length} item(s)',
        isUpToDate: false,
      );
    } catch (e, s) {
      DebugLogger.logError('SYNC', 'Unexpected sync error', e, s);
      return SyncResult(
        success: false,
        itemsSynced: 0,
        message: 'Sync failed: $e',
        isUpToDate: false,
      );
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
