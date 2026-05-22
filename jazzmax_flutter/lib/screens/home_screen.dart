import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../models/catalog_item.dart';
import '../widgets/content_card.dart';
import '../widgets/bottom_nav.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;
  final _searchCtrl = TextEditingController();
  List<CatalogItem>? _searchResults;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(catalogProvider.notifier).initialize();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() { _searchResults = null; _searching = false; });
      return;
    }
    setState(() => _searching = true);
    final results = await ref.read(catalogProvider.notifier).search(query);
    setState(() { _searchResults = results; _searching = false; });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  // Logo
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                      children: [
                        TextSpan(
                          text: 'Jazz',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                        TextSpan(
                          text: 'MAX',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (user != null)
                    GestureDetector(
                      onTap: () =>
                          Navigator.of(context).pushNamed(AppRoutes.profile),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        child: Text(
                          user.phone.isNotEmpty
                              ? user.phone[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Search Bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: _onSearch,
                decoration: InputDecoration(
                  hintText: 'Search movies, shows...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: AppColors.textMuted, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Sync status strip ─────────────────────────────────────────
            if (catalog.status == CatalogStatus.syncing)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: AppColors.primary.withOpacity(0.1),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Syncing catalog...',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: _searchResults != null
                  ? _buildSearchResults()
                  : _buildMainContent(catalog),
            ),
          ],
        ),
      ),
      bottomNavigationBar: JazzMaxBottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          if (i == 2) {
            Navigator.of(context).pushNamed(AppRoutes.subscription);
          } else if (i == 3) {
            Navigator.of(context).pushNamed(AppRoutes.profile);
          }
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searching) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }
    if (_searchResults!.isEmpty) {
      return Center(
        child: Text(
          'No results for "${_searchCtrl.text}"',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2 / 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _searchResults!.length,
      itemBuilder: (_, i) => ContentCard(item: _searchResults![i]),
    );
  }

  Widget _buildMainContent(CatalogState catalog) {
    if (catalog.isEmpty && catalog.status == CatalogStatus.syncing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Loading catalog...',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (catalog.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.movie_outlined,
                color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No content yet',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
            const SizedBox(height: 6),
            const Text(
              'Content is being added — check back soon',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () =>
                  ref.read(catalogProvider.notifier).syncFromServer(),
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (catalog.movies.isNotEmpty) ...[
          _SectionHeader(
            title: 'Movies',
            count: catalog.movies.length,
          ),
          _HorizontalRow(items: catalog.movies),
        ],
        if (catalog.shows.isNotEmpty) ...[
          _SectionHeader(
            title: 'TV Shows',
            count: catalog.shows.length,
          ),
          _HorizontalRow(items: catalog.shows),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalRow extends StatelessWidget {
  final List<CatalogItem> items;
  const _HorizontalRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (_, i) => Padding(
          padding: EdgeInsets.only(right: i < items.length - 1 ? 10 : 0),
          child: SizedBox(width: 130, child: ContentCard(item: items[i])),
        ),
      ),
    );
  }
}
