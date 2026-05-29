import 'dart:async';
import 'package:dio/dio.dart';
import '../constants.dart';
import '../api/api_client.dart';
import '../db/local_db.dart';
import '../debug/debug_logger.dart';

/// Phase 6 — Data Usage Tracking Service.
///
/// Tracks bytes watched locally (SQLite), then flushes to the server
/// when internet is available. Uses optimistic flushing — if the server
/// call fails, the data stays in local DB for the next attempt.
///
/// Usage (from player or app startup):
///   UsageService.addWatchSession(seconds: 120, quality: '720p');
///   UsageService.flushPending();  // called on app resume / sync
class UsageService {
  UsageService._();

  // Quality → estimated bytes per second
  static const Map<String, int> _bpsEstimate = {
    '1080p': 2_200_000,
    '720p':  1_100_000,
    '480p':    600_000,
    '360p':    300_000,
  };

  static int _estimateBytes({required int seconds, required String quality}) {
    final bps = _bpsEstimate[quality] ?? _bpsEstimate['720p']!;
    return (seconds * bps) ~/ 8; // bits → bytes
  }

  /// Called when a watch session ends (player closes / next episode).
  /// [seconds] = seconds actually played (not total duration).
  /// [quality] = '720p', '1080p', etc.
  static Future<void> addWatchSession({
    required int seconds,
    String quality = '720p',
    String? fileId,
  }) async {
    if (seconds <= 0) return;
    final bytes = _estimateBytes(seconds: seconds, quality: quality);
    await LocalDb.addPendingUsage(bytes: bytes);
    DebugLogger.log('USAGE', 'Watch session: ${seconds}s @ $quality → ${(bytes / 1024 / 1024).toStringAsFixed(1)} MB');
    // Try to flush immediately (fire-and-forget)
    flushPending().ignore();
  }

  /// Flush all pending usage bytes to the server.
  /// Safe to call multiple times — idempotent.
  static Future<void> flushPending() async {
    final pending = await LocalDb.getPendingUsageBytes();
    if (pending <= 0) return;
    try {
      final resp = await ApiClient.instance.post(
        ApiPaths.usage,
        data: {'bytes_used': pending},
      );
      final data = resp.data as Map<String, dynamic>? ?? {};
      if (data['ok'] == true) {
        await LocalDb.clearPendingUsage();
        DebugLogger.log('USAGE', 'Flushed ${(pending / 1024 / 1024).toStringAsFixed(1)} MB to server');

        // Update local quota cache from server response
        final quota = data['quota'] as Map<String, dynamic>?;
        if (quota != null) {
          await LocalDb.cacheQuota(quota);
        }
      }
    } on DioException catch (e) {
      // Network error — keep pending bytes for next flush attempt
      DebugLogger.logWarn('USAGE', 'Flush failed (will retry): ${e.type}');
    } catch (e) {
      DebugLogger.logWarn('USAGE', 'Flush error: $e');
    }
  }

  /// Get locally cached quota (used offline / before first server sync).
  static Future<Map<String, dynamic>> getCachedQuota() async {
    return LocalDb.getCachedQuota();
  }

  /// Fetch fresh quota from server (requires internet).
  static Future<Map<String, dynamic>?> fetchQuota() async {
    try {
      final resp = await ApiClient.instance.get(ApiPaths.quota);
      final data = resp.data as Map<String, dynamic>? ?? {};
      if (data['ok'] == true) {
        final quota = data['quota'] as Map<String, dynamic>?;
        if (quota != null) {
          await LocalDb.cacheQuota(quota);
          return quota;
        }
      }
    } catch (_) {}
    return null;
  }
}
