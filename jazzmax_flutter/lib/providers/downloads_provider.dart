import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/db/local_db.dart';
import '../core/download/download_service.dart';

class DownloadsState {
  final List<Map<String, dynamic>> downloads;
  final bool loading;
  final Map<String, double> activeProgress; // fileId → progress

  const DownloadsState({
    this.downloads = const [],
    this.loading = false,
    this.activeProgress = const {},
  });

  DownloadsState copyWith({
    List<Map<String, dynamic>>? downloads,
    bool? loading,
    Map<String, double>? activeProgress,
  }) {
    return DownloadsState(
      downloads: downloads ?? this.downloads,
      loading: loading ?? this.loading,
      activeProgress: activeProgress ?? this.activeProgress,
    );
  }

  bool isDownloading(String fileId) =>
      activeProgress.containsKey(fileId);
  double progressOf(String fileId) =>
      activeProgress[fileId] ?? 0.0;
}

class DownloadsNotifier extends StateNotifier<DownloadsState> {
  DownloadsNotifier() : super(const DownloadsState());

  Future<void> loadDownloads() async {
    state = state.copyWith(loading: true);
    final list = await LocalDb.getDownloads();
    state = state.copyWith(downloads: list, loading: false);
  }

  Future<void> startDownload({
    required String fileId,
    required String titleText,
    required String streamUrl,
    String? posterUrl,
  }) async {
    // Add to active progress
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
    } finally {
      // Remove from active regardless
      final updated = Map<String, double>.from(state.activeProgress);
      updated.remove(fileId);
      state = state.copyWith(activeProgress: updated);
      await loadDownloads();
    }
  }

  Future<void> deleteDownload(String fileId) async {
    await DownloadService.deleteDownload(fileId);
    await loadDownloads();
  }
}

final downloadsProvider =
    StateNotifierProvider<DownloadsNotifier, DownloadsState>(
  (ref) => DownloadsNotifier(),
);
