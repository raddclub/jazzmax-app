import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api/subscription_api.dart';
import '../core/db/local_db.dart';
import '../core/download/download_service.dart';
import '../core/download/download_quota_service.dart';
import '../core/download/background_download_worker.dart';
import '../core/security/encryption_service.dart';
import '../core/constants.dart';

class DownloadsState {
  final List<Map<String, dynamic>> downloads;
  final bool loading;
  final Map<String, double> activeProgress; // fileId → progress
  final String? quotaError;

  const DownloadsState({
    this.downloads = const [],
    this.loading = false,
    this.activeProgress = const {},
    this.quotaError,
  });

  DownloadsState copyWith({
    List<Map<String, dynamic>>? downloads,
    bool? loading,
    Map<String, double>? activeProgress,
    String? quotaError,
    bool clearQuotaError = false,
  }) {
    return DownloadsState(
      downloads: downloads ?? this.downloads,
      loading: loading ?? this.loading,
      activeProgress: activeProgress ?? this.activeProgress,
      quotaError: clearQuotaError ? null : (quotaError ?? this.quotaError),
    );
  }

  bool isDownloading(String fileId) => activeProgress.containsKey(fileId);
  double progressOf(String fileId) => activeProgress[fileId] ?? 0.0;
}

class DownloadsNotifier extends StateNotifier<DownloadsState> {
  DownloadsNotifier() : super(const DownloadsState());

  Future<void> loadDownloads() async {
    state = state.copyWith(loading: true);
    final list = await LocalDb.getDownloads();

    // Encrypt any files downloaded by background worker (is_encrypted=0, completed).
    // This handles the case where the app was killed mid-download and WorkManager
    // finished the download — we encrypt when user re-opens the app.
    for (final d in list) {
      if ((d['status'] as String?) == 'completed' &&
          (d['is_encrypted'] as int? ?? 0) == 0) {
        final path = d['local_path'] as String?;
        if (path != null) {
          _encryptExistingFile(d['file_id'] as String, path);
        }
      }
    }

    final refreshed = await LocalDb.getDownloads();
    state = state.copyWith(downloads: refreshed, loading: false);
  }

  /// Encrypt a plaintext file left by the background worker.
  Future<void> _encryptExistingFile(String fileId, String plainPath) async {
    try {
      final f = File(plainPath);
      if (!await f.exists()) return;
      final encPath = await EncryptionService.encryptFile(plainPath);
      int size = 0;
      try { size = await File(encPath).length(); } catch (_) {}
      await LocalDb.finalizeDownload(fileId, encPath, size);
    } catch (_) {
      // Silent — file stays in private storage even without encryption
    }
  }

  /// Start a foreground download with AES-256 encryption.
  /// Also registers a WorkManager backup so the download survives app kill.
  Future<DownloadResult> startDownload({
    required String fileId,
    required String titleText,
    required String streamUrl,
    String? posterUrl,
  }) async {
    // ── Quota check ────────────────────────────────────────────────────────
    final plan = await _getUserPlan();
    final quota = await DownloadQuotaService.checkQuota(plan);
    if (!quota.allowed) {
      state = state.copyWith(quotaError: quota.denyReason);
      return DownloadResult.quotaExceeded(quota.denyReason!);
    }

    // ── Schedule WorkManager backup task ───────────────────────────────────
    await BackgroundDownloadWorker.schedule(
      fileId: fileId,
      titleText: titleText,
      baseUrl: AppConstants.apiBaseUrl,
    );

    // ── Add to active progress map ─────────────────────────────────────────
    final progress = Map<String, double>.from(state.activeProgress);
    progress[fileId] = 0.0;
    state = state.copyWith(activeProgress: progress);

    try {
      await DownloadService.downloadFile(
        fileId: fileId,
        titleText: titleText,
        streamUrl: streamUrl,
        posterUrl: posterUrl,
        onProgress: (p) {
          final updated = Map<String, double>.from(state.activeProgress);
          updated[fileId] = p;
          state = state.copyWith(activeProgress: updated);
        },
      );
      // Foreground download succeeded — cancel the WorkManager backup
      await BackgroundDownloadWorker.cancel(fileId);
      return DownloadResult.success();
    } catch (e) {
      // WorkManager task stays scheduled to retry in background
      return DownloadResult.error(e.toString());
    } finally {
      final updated = Map<String, double>.from(state.activeProgress);
      updated.remove(fileId);
      state = state.copyWith(activeProgress: updated);
      await loadDownloads();
    }
  }

  Future<void> deleteDownload(String fileId) async {
    await BackgroundDownloadWorker.cancel(fileId);
    await DownloadService.deleteDownload(fileId);
    await loadDownloads();
  }

  void clearQuotaError() {
    state = state.copyWith(clearQuotaError: true);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _getUserPlan() async {
    try {
      final status = await SubscriptionApi.getStatus();
      return (status['plan'] as String? ?? 'free').toLowerCase();
    } catch (_) {
      return 'free';
    }
  }
}

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, DownloadsState>(
  (ref) => DownloadsNotifier(),
);

// ── Result type ───────────────────────────────────────────────────────────────

class DownloadResult {
  final bool success;
  final bool isQuotaError;
  final String? message;

  const DownloadResult._({
    required this.success,
    required this.isQuotaError,
    this.message,
  });

  factory DownloadResult.success() =>
      const DownloadResult._(success: true, isQuotaError: false);

  factory DownloadResult.quotaExceeded(String reason) => DownloadResult._(
        success: false,
        isQuotaError: true,
        message: reason,
      );

  factory DownloadResult.error(String msg) => DownloadResult._(
        success: false,
        isQuotaError: false,
        message: msg,
      );
}
