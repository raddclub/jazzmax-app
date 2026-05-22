import '../api/catalog_api.dart';
import 'local_db.dart';
import '../../models/catalog_item.dart';

/// Handles syncing the catalog from the server into the local SQLite database.
/// On first run: full sync (downloads everything).
/// On subsequent runs: delta sync (only new/changed items since last sync).
class SyncService {
  static Future<SyncResult> sync() async {
    try {
      final lastSyncTs = await LocalDb.getLastSyncTimestamp();
      final serverVersion = await CatalogApi.getVersion();
      final localVersion = await LocalDb.getLastSyncVersion();

      // Check if sync is needed
      if (localVersion >= serverVersion.version && lastSyncTs > 0) {
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
        // First time — full sync
        items = await CatalogApi.syncFull();
      } else {
        // Subsequent — delta sync (only items changed since last sync)
        items = await CatalogApi.syncDelta(lastSyncTs);
      }

      // Write to local DB
      for (final item in items) {
        await LocalDb.upsertTitle(item);

        // Upsert episodes if this is a show
        for (final ep in item.episodes) {
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
        }
      }

      // Update sync metadata
      final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await LocalDb.setLastSyncVersion(serverVersion.version);
      await LocalDb.setLastSyncTimestamp(nowTs);

      return SyncResult(
        success: true,
        itemsSynced: items.length,
        message: 'Synced ${items.length} item(s)',
        isUpToDate: false,
      );
    } catch (e) {
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
