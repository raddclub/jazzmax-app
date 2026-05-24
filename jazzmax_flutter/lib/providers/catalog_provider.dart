import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/db/local_db.dart';
import '../core/db/sync_service.dart';
import '../models/catalog_item.dart';

enum CatalogStatus { idle, syncing, ready, error }

class CatalogState {
  final CatalogStatus status;
  final List<CatalogItem> movies;
  final List<CatalogItem> shows;
  final List<CatalogItem> recentlyWatched;
  final String? error;
  final int totalCount;

  const CatalogState({
    this.status = CatalogStatus.idle,
    this.movies = const [],
    this.shows = const [],
    this.recentlyWatched = const [],
    this.error,
    this.totalCount = 0,
  });

  CatalogState copyWith({
    CatalogStatus? status,
    List<CatalogItem>? movies,
    List<CatalogItem>? shows,
    List<CatalogItem>? recentlyWatched,
    String? error,
    int? totalCount,
  }) {
    return CatalogState(
      status: status ?? this.status,
      movies: movies ?? this.movies,
      shows: shows ?? this.shows,
      recentlyWatched: recentlyWatched ?? this.recentlyWatched,
      error: error,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  bool get isEmpty => movies.isEmpty && shows.isEmpty;
  bool get isReady => status == CatalogStatus.ready;
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  CatalogNotifier() : super(const CatalogState());

  Future<void> initialize() async {
    await _loadFromDb();
    await syncFromServer();
  }

  Future<void> _loadFromDb() async {
    try {
      final movies  = await LocalDb.getMovies();
      final shows   = await LocalDb.getShows();
      final count   = await LocalDb.getTotalCount();
      final recent  = await _loadRecentlyWatched(movies, shows);
      state = state.copyWith(
        status: CatalogStatus.ready,
        movies: movies,
        shows: shows,
        recentlyWatched: recent,
        totalCount: count,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<List<CatalogItem>> _loadRecentlyWatched(
      List<CatalogItem> movies, List<CatalogItem> shows) async {
    try {
      final positions = await LocalDb.getWatchPositions();
      if (positions.isEmpty) return [];
      final all = [...movies, ...shows];
      final result = <CatalogItem>[];
      for (final pos in positions) {
        final fileId   = pos['file_id'] as String? ?? '';
        final posMs    = pos['position_ms'] as int? ?? 0;
        final durMs    = pos['duration_ms'] as int? ?? 0;
        if (posMs < 3000) continue; // Skip if barely watched
        final progress = durMs > 0 ? posMs / durMs : 0.0;
        if (progress > 0.95) continue; // Skip if essentially finished
        // Find the CatalogItem that has this fileId
        final match = all.where((i) => i.fileId == fileId).firstOrNull;
        if (match != null) {
          result.add(match.copyWith(watchProgress: progress));
        }
        if (result.length >= 10) break;
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  Future<void> syncFromServer() async {
    state = state.copyWith(status: CatalogStatus.syncing, error: null);
    final result = await SyncService.sync();
    if (result.success) {
      await _loadFromDb();
    } else {
      state = state.copyWith(
        status: CatalogStatus.ready,
        error: result.itemsSynced == 0 ? result.message : null,
      );
    }
  }

  Future<List<CatalogItem>> search(String query) async {
    if (query.trim().isEmpty) return [];
    return LocalDb.searchTitles(query.trim());
  }
}

final catalogProvider = StateNotifierProvider<CatalogNotifier, CatalogState>(
  (ref) => CatalogNotifier(),
);
