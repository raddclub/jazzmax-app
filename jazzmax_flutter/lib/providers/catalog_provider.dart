import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/db/local_db.dart';
import '../core/db/sync_service.dart';
import '../core/debug/debug_logger.dart';
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
    DebugLogger.log('CATALOG', 'initialize() called');
    await _loadFromDb();
    await syncFromServer();
  }

  Future<void> _loadFromDb() async {
    DebugLogger.logDb('LOAD', 'Querying movies and shows from SQLite...');
    try {
      final movies   = await LocalDb.getMovies();
      final rawShows = await LocalDb.getShows();

      DebugLogger.logDb('LOAD_RESULT',
          'movies=${movies.length}  rawShows=${rawShows.length}');

      // Embed episodes into each show so ShowDetailScreen has them on first open
      final shows = await Future.wait(rawShows.map((show) async {
        final eps = await LocalDb.getEpisodes(show.id);
        return show.copyWithEpisodes(eps);
      }));

      final count  = await LocalDb.getTotalCount();
      final recent = await _loadRecentlyWatched(movies, shows);

      DebugLogger.logDb('LOAD_DONE',
          'movies=${movies.length}  shows=${shows.length}  total=$count  recentlyWatched=${recent.length}');

      if (movies.isEmpty && shows.isEmpty) {
        DebugLogger.logWarn('CATALOG',
            'Both movies and shows are EMPTY after DB load. DB may not have synced yet.');
      } else {
        // Log a few titles to confirm data looks right
        final samples = [...movies, ...shows].take(3).map((i) =>
            '"${i.title}" (${i.mediaType}, free=${i.isFree})').join(', ');
        DebugLogger.log('CATALOG', 'Sample items: $samples');
      }

      state = state.copyWith(
        status: CatalogStatus.ready,
        movies: movies,
        shows: shows,
        recentlyWatched: recent,
        totalCount: count,
      );
    } catch (e, s) {
      DebugLogger.logError('CATALOG', '_loadFromDb threw an exception', e, s);
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
        if (posMs < 3000) continue;
        final progress = durMs > 0 ? posMs / durMs : 0.0;
        if (progress > 0.95) continue;
        final match = all.where((i) => i.fileId == fileId).firstOrNull;
        if (match != null) {
          result.add(match.copyWith(watchProgress: progress));
        }
        if (result.length >= 10) break;
      }
      return result;
    } catch (e) {
      DebugLogger.logError('CATALOG', '_loadRecentlyWatched error', e);
      return [];
    }
  }

  Future<void> syncFromServer() async {
    DebugLogger.logSync('PROVIDER', 'syncFromServer() starting...');
    state = state.copyWith(status: CatalogStatus.syncing, error: null);
    final result = await SyncService.sync();
    DebugLogger.logSync('PROVIDER',
        'SyncService.sync() done — success=${result.success}  items=${result.itemsSynced}  upToDate=${result.isUpToDate}  msg=${result.message}');
    if (result.success) {
      await _loadFromDb();
    } else {
      DebugLogger.logWarn('CATALOG',
          'Sync failed — keeping existing DB data. Error: ${result.message}');
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
