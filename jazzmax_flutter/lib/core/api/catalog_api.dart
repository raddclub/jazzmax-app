import '../constants.dart';
import 'api_client.dart';
import '../../models/catalog_item.dart';
import '../db/local_db.dart';

class CatalogApi {
  static final _client = ApiClient.instance;

  /// Returns the current catalog version number + total item count.
  /// Use this to check if a sync is needed before downloading everything.
  static Future<CatalogVersion> getVersion() async {
    final response = await _client.get(ApiPaths.catalogVersion);
    final data = response.data as Map<String, dynamic>;
    return CatalogVersion(
      version: data['version'] as int? ?? 0,
      count: data['count'] as int? ?? 0,
    );
  }

  /// Full catalog sync. Returns all published titles + their episodes.
  static Future<List<CatalogItem>> syncFull() async {
    final response = await _client.get(ApiPaths.catalogSync);
    final data = response.data as Map<String, dynamic>;
    final items = data['titles'] as List<dynamic>? ?? [];
    return items
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Delta sync — only items changed since [sinceTimestamp].
  /// Pass the last sync time; server returns only new/updated items.
  static Future<List<CatalogItem>> syncDelta(int sinceTimestamp) async {
    final response = await _client.get(
      ApiPaths.catalogSync,
      params: {'since': sinceTimestamp.toString()},
    );
    final data = response.data as Map<String, dynamic>;
    final items = data['titles'] as List<dynamic>? ?? [];
    return items
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get a streaming URL for a specific file.
  ///
  /// CACHING RULE (critical — do not remove):
  /// JazzDrive links are valid for 6 hours. Once generated, the SAME link is
  /// reused for both streaming AND downloading within the 6-hour window.
  /// This keeps JazzDrive requests to the absolute minimum.
  ///
  /// Flow:
  ///   1. Check local device cache → if link exists + not expired → return it
  ///   2. Fetch from server (server calls JazzDrive to generate link)
  ///   3. Save to device cache with 6-hour expiry
  ///   4. Return link
  static Future<String> getStreamUrl(String fileId) async {
    // 1. Check device cache first — avoids hitting JazzDrive again
    final cached = await LocalDb.getCachedStreamUrl(fileId);
    if (cached != null) return cached;

    // 2. Not cached or expired — fetch fresh from server
    final response = await _client.post(ApiPaths.playUrl(fileId));
    final data = response.data as Map<String, dynamic>;
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No stream URL returned from server');
    }

    // 3. Cache on device for 6 hours
    await LocalDb.cacheStreamUrl(fileId, url);

    return url;
  }
}

class CatalogVersion {
  final int version;
  final int count;
  const CatalogVersion({required this.version, required this.count});
}
