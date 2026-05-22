import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/db/local_db.dart';
import '../core/db/sync_service.dart';
import '../models/catalog_item.dart';

enum CatalogStatus { idle, syncing, ready, error }

class CatalogState {
  final CatalogStatus status;
  final List<CatalogItem> movies;
  final List<CatalogItem> shows;
  final String? error;
  final int totalCount;

  const CatalogState({
    this.status = CatalogStatus.idle,
    this.movies = const [],
    this.shows = const [],
    this.error,
    this.totalCount = 0,
  });

  CatalogState copyWith({
    CatalogStatus? status,
    List<CatalogItem>? movies,
    List<CatalogItem>? shows,
    String? error,
    int? totalCount,
  }) {
    return CatalogState(
      status: status ?? this.status,
      movies: movies ?? this.movies,
      shows: shows ?? this.shows,
      error: error,
      totalCount: totalCount ?? this.totalCount,
    );
  }

  bool get isEmpty => movies.isEmpty && shows.isEmpty;
  bool get isReady => status == CatalogStatus.ready;
}

class CatalogNotifier extends StateNotifier<CatalogState> {
  CatalogNotifier() : super(const CatalogState());

  /// Load from local DB first (instant), then sync from server in background.
  Future<void> initialize() async {
    await _loadFromDb();
    await syncFromServer();
  }

  Future<void> _loadFromDb() async {
    try {
      final movies = await LocalDb.getMovies();
      final shows = await LocalDb.getShows();
      final count = await LocalDb.getTotalCount();
      state = state.copyWith(
        status: CatalogStatus.ready,
        movies: movies,
        shows: shows,
        totalCount: count,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> syncFromServer() async {
    state = state.copyWith(status: CatalogStatus.syncing, error: null);
    final result = await SyncService.sync();
    if (result.success) {
      await _loadFromDb();
    } else {
      // Sync failed but we still have local data — show it
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
