import '../constants.dart';
import 'api_client.dart';
import '../../models/catalog_item.dart';

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
    final rawTitles = data['titles'] as List<dynamic>? ?? [];
    final rawEpisodes = data['episodes'] as List<dynamic>? ?? [];
    // Build episode lookup: titleId → list of episode maps
    final epsByTitle = <int, List<Map<String, dynamic>>>{};
    for (final ep in rawEpisodes) {
      final e = ep as Map<String, dynamic>;
      final tid = e['title_id'] as int? ?? 0;
      epsByTitle.putIfAbsent(tid, () => []).add(e);
    }
    return rawTitles.map((e) {
      final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
      m['episodes'] = epsByTitle[m['id'] as int? ?? 0] ?? [];
      return CatalogItem.fromJson(m);
    }).toList();
  }

  /// Delta sync — only items changed since [sinceTimestamp].
  /// Pass the last sync time; server returns only new/updated items.
  static Future<List<CatalogItem>> syncDelta(int sinceTimestamp) async {
    final response = await _client.get(
      ApiPaths.catalogSync,
      params: {'since': sinceTimestamp.toString()},
    );
    final data = response.data as Map<String, dynamic>;
    final rawTitles = data['titles'] as List<dynamic>? ?? [];
    final rawEpisodes = data['episodes'] as List<dynamic>? ?? [];
    final epsByTitle = <int, List<Map<String, dynamic>>>{};
    for (final ep in rawEpisodes) {
      final e = ep as Map<String, dynamic>;
      final tid = e['title_id'] as int? ?? 0;
      epsByTitle.putIfAbsent(tid, () => []).add(e);
    }
    return rawTitles.map((e) {
      final m = Map<String, dynamic>.from(e as Map<String, dynamic>);
      m['episodes'] = epsByTitle[m['id'] as int? ?? 0] ?? [];
      return CatalogItem.fromJson(m);
    }).toList();
  }

  /// Get a streaming URL for a specific file.
  /// This is always fetched fresh — never cached in local DB.
  /// Server generates a time-limited JazzDrive link (valid ~6 hours).
  static Future<String> getStreamUrl(String fileId) async {
    final response = await _client.post(ApiPaths.playUrl(fileId));
    final data = response.data as Map<String, dynamic>;
    final url = data['url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('No stream URL returned from server');
    }
    return url;
  }
}

class CatalogVersion {
  final int version;
  final int count;
  const CatalogVersion({required this.version, required this.count});
}
