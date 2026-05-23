import 'dart:convert';
import '../constants.dart';
import 'api_client.dart';
import '../../models/catalog_item.dart';

/// Holds the full result of a catalog sync — titles + any TV episodes.
class CatalogSyncData {
  final List<CatalogItem> titles;
  final List<Map<String, dynamic>> episodes;
  const CatalogSyncData({required this.titles, required this.episodes});
}

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
  static Future<CatalogSyncData> syncFull() async {
    final response = await _client.get(ApiPaths.catalogSync);
    return _parseSyncResponse(response.data);
  }

  /// Delta sync — only items changed since [sinceTimestamp].
  static Future<CatalogSyncData> syncDelta(int sinceTimestamp) async {
    final response = await _client.get(
      ApiPaths.catalogSync,
      params: {'since': sinceTimestamp.toString()},
    );
    return _parseSyncResponse(response.data);
  }

  static CatalogSyncData _parseSyncResponse(dynamic raw) {
    final data = raw as Map<String, dynamic>;

    // Server returns 'titles' key (not 'items')
    final titlesRaw = data['titles'] as List<dynamic>? ?? [];
    final titles = titlesRaw
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // Top-level episodes list for TV shows
    final episodesRaw = data['episodes'] as List<dynamic>? ?? [];
    final episodes = episodesRaw
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return CatalogSyncData(titles: titles, episodes: episodes);
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
