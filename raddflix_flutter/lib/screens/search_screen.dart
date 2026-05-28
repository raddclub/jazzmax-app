import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants.dart';
import '../providers/catalog_provider.dart';
import '../models/catalog_item.dart';
import '../widgets/content_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  List<CatalogItem>? _results;
  bool _loading = false;
  List<String> _history = [];

  // Active filters
  String? _typeFilter;   // null = All | 'Movies' | 'Shows'
  String? _genreFilter;  // null = any genre
  int?    _yearFilter;   // null = any year

  // Focus glow animation
  late final AnimationController _glowCtrl;
  late final Animation<double>   _glowAnim;

  static const _staticTrending = [
    'Money Heist', 'Squid Game', 'Ertugrul', 'Kabul Express',
    'Parizaad', 'Tere Bin', 'House of the Dragon', 'The Batman',
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);
    _focus.addListener(() {
      if (_focus.hasFocus) _glowCtrl.forward(); else _glowCtrl.reverse();
    });
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final f = args?['initialFilter'] as String?;
      if (f != null && f != 'All' && mounted) setState(() => _typeFilter = f);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    _glowCtrl.dispose();
    super.dispose();
  }

  // ── History ─────────────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(StorageKeys.searchHistory) ?? [];
    if (mounted) setState(() => _history = raw);
  }

  Future<void> _saveToHistory(String q) async {
    if (q.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final list = [q, ..._history.where((h) => h != q)].take(10).toList();
    await prefs.setStringList(StorageKeys.searchHistory, list);
    if (mounted) setState(() => _history = list);
  }

  Future<void> _removeFromHistory(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final list = _history.where((h) => h != q).toList();
    await prefs.setStringList(StorageKeys.searchHistory, list);
    if (mounted) setState(() => _history = list);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.searchHistory);
    if (mounted) setState(() => _history = []);
  }

  // ── Search logic ─────────────────────────────────────────────────────────────

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    setState(() {}); // redraw for clear-button + filter visibility
    if (q.trim().isEmpty) {
      setState(() { _results = null; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 320), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    if (!mounted) return;
    try {
      final raw      = await ref.read(catalogProvider.notifier).search(q);
      final filtered = _applyFilters(raw);
      if (mounted) setState(() { _results = filtered; _loading = false; });
      await _saveToHistory(q);
    } catch (_) {
      if (mounted) setState(() { _results = []; _loading = false; });
    }
  }

  List<CatalogItem> _applyFilters(List<CatalogItem> items) {
    return items.where((item) {
      if (_typeFilter == 'Movies' && !item.isMovie)  return false;
      if (_typeFilter == 'Shows'  && !item.isShow)   return false;
      if (_genreFilter != null) {
        if (!(item.genres ?? '').toLowerCase().contains(_genreFilter!.toLowerCase())) return false;
      }
      if (_yearFilter != null && item.year != _yearFilter) return false;
      return true;
    }).toList();
  }

  void _onFilterChanged() {
    if (_ctrl.text.isNotEmpty) {
      setState(() => _loading = true);
      _doSearch(_ctrl.text);
    } else {
      setState(() {});
    }
  }

  void _tapSuggestion(String q) {
    _ctrl.text = q;
    _ctrl.selection = TextSelection.collapsed(offset: q.length);
    _doSearch(q);
  }

  void _clearFilters() {
    setState(() { _typeFilter = null; _genreFilter = null; _yearFilter = null; });
    if (_ctrl.text.isNotEmpty) _doSearch(_ctrl.text);
  }

  // ── Catalog helpers ──────────────────────────────────────────────────────────

  List<String> _extractGenres(List<CatalogItem> all) {
    final counts = <String, int>{};
    for (final item in all) {
      for (final g in (item.genres ?? '').split(',')) {
        final t = g.trim();
        if (t.isNotEmpty) counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(8).map((e) => e.key).toList();
  }

  List<int> _extractYears(List<CatalogItem> all) {
    return all.map((i) => i.year).whereType<int>().toSet().toList()
      ..sort((a, b) => b.compareTo(a));
  }

  List<CatalogItem> _discoverItems(List<CatalogItem> all) {
    if (_typeFilter == 'Movies') return all.where((i) => i.isMovie).toList();
    if (_typeFilter == 'Shows')  return all.where((i) => i.isShow).toList();
    return all;
  }

  Map<String, List<CatalogItem>> _byGenre(List<CatalogItem> all, List<String> genres) {
    final map = <String, List<CatalogItem>>{};
    for (final genre in genres) {
      final items = all
          .where((i) => (i.genres ?? '').toLowerCase().contains(genre.toLowerCase()))
          .toList();
      if (items.length >= 2) map[genre] = items;
    }
    return map;
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final catalog   = ref.watch(catalogProvider);
    final allItems  = [...catalog.movies, ...catalog.shows];
    final genres    = _extractGenres(allItems);
    final years     = _extractYears(allItems);
    final hasQuery  = _ctrl.text.isNotEmpty;
    final hasFilter = _typeFilter != null || _genreFilter != null || _yearFilter != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          _buildSearchBar(),
          _buildTypeChips(),
          if ((hasQuery || hasFilter) && (genres.isNotEmpty || years.isNotEmpty))
            _buildGenreYearChips(genres, years),
          const SizedBox(height: 6),
          Expanded(child: _buildBody(allItems, genres, years, catalog.trending, hasQuery)),
        ]),
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, child) => Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: Color.lerp(AppColors.glassBorder, AppColors.primary, _glowAnim.value)!,
                  width: 1 + _glowAnim.value * 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.18 * _glowAnim.value),
                    blurRadius: 20, spreadRadius: -2),
                ],
              ),
              child: child,
            ),
            child: Row(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _loading
                      ? const SizedBox(key: ValueKey('spin'), width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(AppColors.primary)))
                      : const Icon(key: ValueKey('icon'),
                          Icons.search_rounded, color: AppColors.textMuted, size: 22),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: 'Movies, shows, dramas…',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                    filled: false,
                  ),
                  onChanged: _onQueryChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _doSearch,
                ),
              ),
              if (_ctrl.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                  onPressed: () {
                    _ctrl.clear();
                    setState(() { _results = null; _loading = false; });
                    _focus.requestFocus();
                  },
                ),
            ]),
          ),
        ),
      ]),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.1, end: 0, duration: 250.ms);
  }

  // ── Type chips (All / Movies / Shows) ────────────────────────────────────────

  Widget _buildTypeChips() {
    final types  = [null,  'Movies', 'Shows'];
    final labels = ['All', 'Movies', 'Shows'];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: types.length,
        itemBuilder: (_, i) {
          final active = _typeFilter == types[i];
          return GestureDetector(
            onTap: () { setState(() => _typeFilter = types[i]); _onFilterChanged(); },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                gradient: active ? AppColors.primaryGradient : null,
                color: active ? null : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.round),
                border: Border.all(color: active ? Colors.transparent : AppColors.glassBorder),
                boxShadow: active ? AppShadows.primary : null,
              ),
              child: Text(labels[i], style: TextStyle(
                color: active ? Colors.white : AppColors.textMuted,
                fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
            ),
          );
        },
      ),
    );
  }

  // ── Genre + Year chips ────────────────────────────────────────────────────────

  Widget _buildGenreYearChips(List<String> genres, List<int> years) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        children: [
          if (genres.isNotEmpty) ...[
            ...genres.map((g) {
              final active = _genreFilter == g;
              return GestureDetector(
                onTap: () { setState(() => _genreFilter = active ? null : g); _onFilterChanged(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary.withOpacity(0.15) : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.round),
                    border: Border.all(
                      color: active ? AppColors.primary : AppColors.glassBorder,
                      width: active ? 1.5 : 1),
                  ),
                  child: Text(g, style: TextStyle(
                    color: active ? AppColors.primary : AppColors.textMuted,
                    fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
                ),
              );
            }),
          ],
          // Separator
          if (genres.isNotEmpty && years.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              width: 1, color: AppColors.divider),
          // Year chips
          if (years.isNotEmpty) ...[
            ...years.take(5).map((y) {
              final active = _yearFilter == y;
              return GestureDetector(
                onTap: () { setState(() => _yearFilter = active ? null : y); _onFilterChanged(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: active ? AppColors.accent.withOpacity(0.15) : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.round),
                    border: Border.all(
                      color: active ? AppColors.accent : AppColors.glassBorder,
                      width: active ? 1.5 : 1),
                  ),
                  child: Text('$y', style: TextStyle(
                    color: active ? AppColors.accent : AppColors.textMuted,
                    fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
                ),
              );
            }),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.3, end: 0, duration: 200.ms);
  }

  // ── Body dispatcher ──────────────────────────────────────────────────────────

  Widget _buildBody(
      List<CatalogItem> allItems, List<String> genres, List<int> years, List<CatalogItem> trending, bool hasQuery) {
    if (_loading) return _buildShimmer();
    if (_results != null) return _buildResults();
    return _buildDiscover(allItems, genres, trending);
  }

  // ── Shimmer ──────────────────────────────────────────────────────────────────

  Widget _buildShimmer() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 2/3, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: 9,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.surfaceHigh,
        child: Container(decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.sm))),
      ),
    );
  }

  // ── Results ──────────────────────────────────────────────────────────────────

  Widget _buildResults() {
    final hasActiveFilter = _typeFilter != null || _genreFilter != null || _yearFilter != null;

    if (_results!.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          Text('"${_ctrl.text}"',
              style: const TextStyle(color: AppColors.textPrimary,
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('No results found. Try different keywords.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center),
          if (hasActiveFilter) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Clear filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary)),
              onPressed: _clearFilters,
            ),
          ],
        ]).animate().fadeIn(duration: 300.ms),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
                child: Text('${_results!.length}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              Text(' result${_results!.length == 1 ? "" : "s"} for "${_ctrl.text}"',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              if (hasActiveFilter) ...[
                const Spacer(),
                GestureDetector(
                  onTap: _clearFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppRadius.round),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3))),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.filter_alt_off_rounded, size: 12, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Clear', style: TextStyle(
                          color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (_, i) => ContentCard(item: _results![i])
                  .animate(delay: (i * 25).ms).fadeIn(duration: 250.ms)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1),
                      duration: 250.ms, curve: AppCurves.standard),
              childCount: _results!.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, childAspectRatio: 2/3,
                crossAxisSpacing: 10, mainAxisSpacing: 10),
          ),
        ),
      ],
    );
  }

  // ── Discover ─────────────────────────────────────────────────────────────────

  Widget _buildDiscover(List<CatalogItem> allItems, List<String> genres, List<CatalogItem> trendingItems) {
    final discover = _discoverItems(allItems);
    final byGenre  = _byGenre(discover, genres);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Recent searches ────────────────────────────────────────────────
        if (_history.isNotEmpty) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Row(children: [
              Icon(Icons.history_rounded, color: AppColors.textMuted, size: 16),
              SizedBox(width: 8),
              Text('Recent Searches', style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            TextButton(
              onPressed: _clearHistory,
              style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
              child: const Text('Clear all', style: TextStyle(fontSize: 13))),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _history.map((h) => _HistoryPill(
              text: h,
              onTap: () => _tapSuggestion(h),
              onDelete: () => _removeFromHistory(h),
            )).toList()),
          const SizedBox(height: 28),
        ],

        // ── Trending ───────────────────────────────────────────────────────
        Row(children: [
          Icon(Icons.local_fire_department_rounded, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          const Text('Trending', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
          if (trendingItems.isNotEmpty) ...[
            SizedBox(
              height: 185,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: trendingItems.length,
                itemBuilder: (_, i) => Padding(
                  padding: EdgeInsets.only(right: i < trendingItems.length - 1 ? 10 : 0),
                  child: SizedBox(
                    width: 114,
                    child: ContentCard(item: trendingItems[i])
                        .animate(delay: (i * 40).ms)
                        .fadeIn(duration: 280.ms)
                        .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1),
                            duration: 280.ms, curve: AppCurves.enter),
                  ),
                ),
              ),
            ),
          ] else ...[
            ..._staticTrending.asMap().entries.map((e) =>
              _TrendingRow(rank: e.key + 1, label: e.value, onTap: () => _tapSuggestion(e.value))
                  .animate(delay: (e.key * 40).ms)
                  .fadeIn(duration: 280.ms)
                  .slideX(begin: 0.15, end: 0, duration: 280.ms, curve: AppCurves.standard)),
          ],

        // ── Browse by Genre ────────────────────────────────────────────────
        if (byGenre.isNotEmpty) ...[
          const SizedBox(height: 28),
          Row(children: [
            Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              _typeFilter != null ? 'Browse $_typeFilter' : 'Browse by Genre',
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          ...byGenre.entries.toList().asMap().entries.map((outer) {
            final entry = outer.value;
            return _GenreRow(
              genre: entry.key,
              items: entry.value,
              onTapSeeAll: () => _tapSuggestion(entry.key),
            ).animate(delay: (outer.key * 60).ms).fadeIn(duration: 300.ms);
          }),
        ],

        // Empty discover state (catalog still loading)
        if (allItems.isEmpty) ...[
          const SizedBox(height: 40),
          Center(child: Column(children: [
            const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text('Start typing to search', style: TextStyle(color: AppColors.textMuted)),
          ])),
        ],
      ]),
    );
  }
}

// ── History Pill ──────────────────────────────────────────────────────────────
class _HistoryPill extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _HistoryPill({required this.text, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.round),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.history_rounded, size: 13, color: AppColors.textMuted),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(text, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDelete,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 13, color: AppColors.textMuted))),
        ]),
      ),
    );
  }
}

// ── Trending Row ──────────────────────────────────────────────────────────────
class _TrendingRow extends StatelessWidget {
  final int rank;
  final String label;
  final VoidCallback onTap;
  const _TrendingRow({required this.rank, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.glassBorder),
        ),
        child: Row(children: [
          SizedBox(
            width: 26,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (b) => AppColors.primaryGradient.createShader(b),
              child: Text('$rank', style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
          Icon(Icons.north_east_rounded, color: AppColors.textMuted, size: 16),
        ]),
      ),
    );
  }
}

// ── Genre Row ─────────────────────────────────────────────────────────────────
class _GenreRow extends StatelessWidget {
  final String genre;
  final List<CatalogItem> items;
  final VoidCallback onTapSeeAll;
  const _GenreRow({required this.genre, required this.items, required this.onTapSeeAll});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 3, height: 16,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2)),
        ),
        Expanded(child: Text(genre, style: const TextStyle(
            color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700))),
        TextButton(
          onPressed: onTapSeeAll,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary,
              padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('See all', style: TextStyle(fontSize: 12))),
      ]),
      const SizedBox(height: 10),
      SizedBox(
        height: 160,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? 10 : 0),
            child: SizedBox(width: 106, child: ContentCard(item: items[i]))),
        ),
      ),
      const SizedBox(height: 20),
    ]);
  }
}
