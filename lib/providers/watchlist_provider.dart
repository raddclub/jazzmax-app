import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/db/local_db.dart';
import '../models/catalog_item.dart';

class WatchlistState {
  final List<CatalogItem> items;
  final Set<int> watchlistIds;
  final bool loading;
  final String? error;

  const WatchlistState({
    this.items = const [],
    this.watchlistIds = const {},
    this.loading = false,
    this.error,
  });

  WatchlistState copyWith({
    List<CatalogItem>? items,
    Set<int>? watchlistIds,
    bool? loading,
    String? error,
  }) {
    return WatchlistState(
      items: items ?? this.items,
      watchlistIds: watchlistIds ?? this.watchlistIds,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class WatchlistNotifier extends StateNotifier<WatchlistState> {
  WatchlistNotifier() : super(const WatchlistState());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final items = await LocalDb.getWatchlist();
      final ids = items.map((i) => i.id).toSet();
      state = state.copyWith(items: items, watchlistIds: ids, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> checkWatchlist(int titleId) async {
    final ids = await LocalDb.getWatchlistIds();
    state = state.copyWith(watchlistIds: ids);
  }

  Future<void> toggle(CatalogItem item) async {
    state = state.copyWith(loading: true);
    try {
      if (state.watchlistIds.contains(item.id)) {
        await LocalDb.removeFromWatchlist(item.id);
        final newIds = Set<int>.from(state.watchlistIds)..remove(item.id);
        final newItems = state.items.where((i) => i.id != item.id).toList();
        state = state.copyWith(
          items: newItems,
          watchlistIds: newIds,
          loading: false,
        );
      } else {
        await LocalDb.addToWatchlist(item);
        final newIds = Set<int>.from(state.watchlistIds)..add(item.id);
        final newItems = [item, ...state.items];
        state = state.copyWith(
          items: newItems,
          watchlistIds: newIds,
          loading: false,
        );
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }
}

final watchlistProvider =
    StateNotifierProvider<WatchlistNotifier, WatchlistState>(
  (ref) => WatchlistNotifier(),
);
