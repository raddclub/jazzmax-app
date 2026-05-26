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
    final titles   = data['titles']   as List<dynamic>? ?? [];
    final episodes = data['episodes'] as List<dynamic>? ?? [];
    return _buildItemsWithEpisodes(titles, episodes);
  }

  /// Delta sync — only items changed since [sinceTimestamp].
  /// Pass the last sync time; server returns only new/updated items.
  static Future<List<CatalogItem>> syncDelta(int sinceTimestamp) async {
    final response = await _client.get(
      ApiPaths.catalogSync,
      params: {'since': sinceTimestamp.toString()},
    );
    final data = response.data as Map<String, dynamic>;
    final titles   = data['titles']   as List<dynamic>? ?? [];
    final episodes = data['episodes'] as List<dynamic>? ?? [];
    return _buildItemsWithEpisodes(titles, episodes);
  }

  /// Attaches episodes to their parent CatalogItems.
  static List<CatalogItem> _buildItemsWithEpisodes(
    List<dynamic> titles, List<dynamic> episodes) {
    final epsByTitle = <int, List<Map<String, dynamic>>>{};
    for (final ep in episodes) {
      final m = ep as Map<String, dynamic>;
      final tid = m['title_id'] as int? ?? 0;
      epsByTitle.putIfAbsent(tid, () => []).add(m);
    }
    return titles.map((e) {
      final item = CatalogItem.fromJson(e as Map<String, dynamic>);
      final eps = epsByTitle[item.id] ?? [];
      return eps.isEmpty ? item : item.copyWithEpisodes(eps);
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
