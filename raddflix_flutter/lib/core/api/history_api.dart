import '../api/api_client.dart';

/// BUG-A08 / BUG-A19: Watch history API client.
///
/// Syncs local watch positions to the server so history is accessible
/// across devices. Previously no HistoryApi class existed — the server
/// endpoints at /api/history/* were completely unused by the Flutter app.
///
/// BUG-A11 note: server stores position_ms and duration_ms in milliseconds.
/// The watched_at field returned by GET /api/history is epoch SECONDS (not ms).
/// Always parse it as: DateTime.fromMillisecondsSinceEpoch(watchedAt * 1000).
class HistoryApi {
  /// POST /api/history/<fileId>
  /// Sends current position to server. Called on player exit.
  /// Fire-and-forget: errors are silently ignored (offline is normal).
  static Future<void> syncPosition({
    required String fileId,
    required int positionMs,
    required int durationMs,
  }) async {
    if (fileId.isEmpty || positionMs <= 0) return;
    try {
      await ApiClient.instance.post(
        '/api/history/$fileId',
        data: {
          'position_ms': positionMs,
          'duration_ms': durationMs,
        },
      );
    } catch (_) {
      // Offline or auth error — local DB already has the position, ignore.
    }
  }

  /// GET /api/history
  /// Returns the server-side watch history list.
  /// Each entry: {file_id, position_ms, duration_ms, watched_at (epoch seconds)}.
  /// Returns empty list on any error.
  static Future<List<Map<String, dynamic>>> getHistory() async {
    try {
      final resp = await ApiClient.instance.get('/api/history');
      final data = resp.data;
      if (data is Map && data['ok'] == true) {
        final list = data['history'];
        if (list is List) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Parse watched_at from server response correctly.
  /// Server returns epoch SECONDS; DateTime needs milliseconds (BUG-A11).
  static DateTime watchedAtToDateTime(dynamic watchedAt) {
    final secs = (watchedAt as num?)?.toInt() ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000);
  }
}
