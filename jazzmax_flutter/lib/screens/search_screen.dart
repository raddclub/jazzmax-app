import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../providers/catalog_provider.dart';
import '../models/catalog_item.dart';
import '../widgets/content_card.dart';
import 'package:shimmer/shimmer.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<CatalogItem>? _results;
  bool _loading = false;
  List<String> _history = [];
  String? _activeFilter;

  static const _filters = ['All', 'Movies', 'Shows', 'Urdu', 'English', 'Punjabi'];
  static const _trending = [
    'Money Heist', 'Squid Game', 'Ertugrul', 'Kabul Express',
    'Parizaad', 'Meray Qatil Meray Dildar', 'Tere Bin',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focus.requestFocus();
      // Read initialFilter passed from home screen See-All
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        final f = args['initialFilter'] as String?;
        if (f != null && mounted) setState(() => _activeFilter = f);
      }
    });
  }

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
    setState(() => _history = list);
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) { setState(() { _results = null; _loading = false; }); return; }
    setState(() => _loading = true);
    final results = await ref.read(catalogProvider.notifier).search(q);
    final filtered = _applyFilter(results);
    setState(() { _results = filtered; _loading = false; });
    await _saveToHistory(q);
  }

  List<CatalogItem> _applyFilter(List<CatalogItem> items) {
    if (_activeFilter == null || _activeFilter == 'All') return items;
    switch (_activeFilter) {
      case 'Movies':  return items.where((i) => i.isMovie).toList();
      case 'Shows':   return items.where((i) => i.isShow).toList();
      case 'Urdu':    return items.where((i) => (i.language ?? '').toLowerCase().contains('urdu')).toList();
      case 'English': return items.where((i) => (i.language ?? '').toLowerCase().contains('english')).toList();
      case 'Punjabi': return items.where((i) => (i.language ?? '').toLowerCase().contains('punjabi')).toList();
      default: return items;
    }
  }

  void _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.searchHistory);
    setState(() => _history = []);
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: null,
      body: SafeArea(
        child: Column(children: [
          // Search bar row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 22)),
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Movies, shows, dramas…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 14),
                          filled: false,
                        ),
                        onChanged: _search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _search,
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
          ).animate().fadeIn(duration: 300.ms),

          // Filter chips (shown when searching)
          if (_results != null || _ctrl.text.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                itemCount: _filters.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () {
                    setState(() => _activeFilter = _filters[i] == 'All' ? null : _filters[i]);
                    if (_ctrl.text.isNotEmpty) _search(_ctrl.text);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_activeFilter == _filters[i] || (_activeFilter == null && _filters[i] == 'All'))
                          ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.round),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Text(_filters[i], style: TextStyle(
                      color: (_activeFilter == _filters[i] || (_activeFilter == null && _filters[i] == 'All'))
                          ? Colors.white : AppColors.textMuted,
                      fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.2, end: 0, duration: 250.ms),

          const SizedBox(height: 8),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoadingGrid();
    if (_results != null) return _buildResults();
    return _buildDiscover();
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 2/3, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: 9,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppColors.surface,
        highlightColor: AppColors.border,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_results!.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 56),
          const SizedBox(height: 16),
          Text('No results for "${_ctrl.text}"',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Try different keywords',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ]).animate().fadeIn(duration: 300.ms),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 2/3, crossAxisSpacing: 10, mainAxisSpacing: 10),
      itemCount: _results!.length,
      itemBuilder: (_, i) => ContentCard(item: _results![i])
          .animate(delay: (i * 25).ms).fadeIn(duration: 250.ms)
          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 250.ms),
    );
  }

  Widget _buildDiscover() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Recent searches
        if (_history.isNotEmpty) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Recent', style: TextStyle(color: AppColors.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w700)),
            TextButton(onPressed: _clearHistory,
                child: const Text('Clear', style: TextStyle(color: AppColors.textMuted, fontSize: 13))),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _history.map((h) =>
            GestureDetector(
              onTap: () { _ctrl.text = h; _search(h); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.round),
                    border: Border.all(color: AppColors.glassBorder)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.history_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(h, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
            )).toList()),
          const SizedBox(height: 24),
        ],
        // Trending
        const Text('Trending Now', style: TextStyle(color: AppColors.textPrimary,
            fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ..._trending.asMap().entries.map((e) => GestureDetector(
          onTap: () { _ctrl.text = e.value; _search(e.value); },
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(children: [
              Container(width: 28, height: 28,
                decoration: BoxDecoration(shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.12)),
                child: Center(child: Text('${e.key + 1}',
                    style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 12),
              Expanded(child: Text(e.value,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14))),
              const Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 18),
            ]),
          ),
        ).animate(delay: (e.key * 40).ms).fadeIn(duration: 300.ms)
            .slideX(begin: 0.2, end: 0, duration: 300.ms, curve: AppCurves.standard)),
      ]),
    );
  }
}
