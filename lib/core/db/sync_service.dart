import '../api/catalog_api.dart';
import 'local_db.dart';

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
      CatalogSyncData syncData;
      if (lastSyncTs == 0) {
        // First time — full sync
        syncData = await CatalogApi.syncFull();
      } else {
        // Subsequent — delta sync (only items changed since last sync)
        syncData = await CatalogApi.syncDelta(lastSyncTs);
      }

      // Write titles to local DB
      for (final item in syncData.titles) {
        await LocalDb.upsertTitle(item);
      }

      // Write top-level episodes (TV show episodes keyed by their file id)
      for (final ep in syncData.episodes) {
        // Episode 'id' from server IS the file_id (files table row id)
        final fileId = ep['id']?.toString();
        final titleId = ep['title_id'];
        if (fileId == null || titleId == null) continue;

        final isFreeRaw = ep['is_free'];
        final isFree = (isFreeRaw == true || isFreeRaw == 1) ? 1 : 0;

        await LocalDb.upsertEpisode({
          'id': ep['id'],
          'title_id': titleId,
          'file_id': fileId,
          'season': ep['season'],
          'episode': ep['episode'],
          'label': ep['label'],
          'quality': null,
          'is_free': isFree,
        });
      }

      // Update sync metadata
      final nowTs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await LocalDb.setLastSyncVersion(serverVersion.version);
      await LocalDb.setLastSyncTimestamp(nowTs);

      return SyncResult(
        success: true,
        itemsSynced: syncData.titles.length,
        message: 'Synced ${syncData.titles.length} title(s)',
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
