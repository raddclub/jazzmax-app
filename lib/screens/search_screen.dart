import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../core/db/local_db.dart';
import '../models/catalog_item.dart';
import '../widgets/content_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  List<CatalogItem> _results = [];
  bool _searching = false;
  bool _hasSearched = false;

  String _typeFilter = 'all';
  String? _genreFilter;
  bool _freeOnly = false;

  static const List<String> _genres = [
    'Action', 'Drama', 'Comedy', 'Romance', 'Thriller',
    'Horror', 'Family', 'Animation', 'Crime', 'Documentary',
    'Sci-Fi', 'Fantasy', 'History', 'Biography', 'Music',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    setState(() { _searching = true; _hasSearched = true; });
    final results = await LocalDb.searchFiltered(
      query: _ctrl.text.trim(),
      mediaType: _typeFilter == 'all' ? null : _typeFilter,
      genre: _genreFilter,
      freeOnly: _freeOnly,
    );
    if (mounted) setState(() { _results = results; _searching = false; });
  }

  void _clearFilters() {
    setState(() { _genreFilter = null; _typeFilter = 'all'; _freeOnly = false; });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          // ── Search field ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: _onChanged,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Movies, shows, genres...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                suffixIcon: _ctrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textMuted, size: 18),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() { _results = []; _hasSearched = false; });
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Type + Free filters ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _Chip(label: 'All',      value: 'all',   current: _typeFilter, onTap: (v) { setState(() => _typeFilter = v); _search(); }),
                const SizedBox(width: 8),
                _Chip(label: '🎬 Movies', value: 'movie', current: _typeFilter, onTap: (v) { setState(() => _typeFilter = v); _search(); }),
                const SizedBox(width: 8),
                _Chip(label: '📺 Shows',  value: 'show',  current: _typeFilter, onTap: (v) { setState(() => _typeFilter = v); _search(); }),
                const Spacer(),
                GestureDetector(
                  onTap: () { setState(() => _freeOnly = !_freeOnly); _search(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _freeOnly ? AppColors.success : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _freeOnly ? AppColors.success : AppColors.divider),
                    ),
                    child: Text('FREE',
                      style: TextStyle(
                        color: _freeOnly ? Colors.white : AppColors.textMuted,
                        fontSize: 11, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Genre chips ──────────────────────────────────────────────────
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _genres.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final g = _genres[i];
                final sel = _genreFilter == g;
                return GestureDetector(
                  onTap: () { setState(() => _genreFilter = sel ? null : g); _search(); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.divider),
                    ),
                    child: Text(g,
                      style: TextStyle(
                        color: sel ? Colors.white : AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),

          // ── Results ──────────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
      ));
    }

    if (!_hasSearched) {
      return _buildSuggestions();
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 56),
            const SizedBox(height: 16),
            Text(
              _ctrl.text.trim().isEmpty ? 'No results for these filters' : 'No results for "${_ctrl.text}"',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clearFilters,
              child: const Text('Clear filters', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text('${_results.length} result${_results.length == 1 ? '' : 's'}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, childAspectRatio: 2 / 3,
              crossAxisSpacing: 10, mainAxisSpacing: 10,
            ),
            itemCount: _results.length,
            itemBuilder: (_, i) => ContentCard(item: _results[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Popular Genres',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _genres.take(10).map((g) => GestureDetector(
              onTap: () { setState(() { _genreFilter = g; _hasSearched = true; }); _search(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(g, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _Chip({required this.label, required this.value, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
          style: TextStyle(
            color: sel ? Colors.white : AppColors.textMuted,
            fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
