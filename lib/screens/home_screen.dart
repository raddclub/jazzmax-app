import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/db/local_db.dart';
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
  List<Map<String, dynamic>> _continueWatching = [];
  List<CatalogItem> _freeItems = [];
  List<CatalogItem> _newReleases = [];
  bool _loadingExtras = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(catalogProvider.notifier).initialize();
      _loadExtras();
    });
  }

  Future<void> _loadExtras() async {
    if (_loadingExtras) return;
    setState(() => _loadingExtras = true);
    final results = await Future.wait([
      LocalDb.getContinueWatching(),
      LocalDb.getFreeItems(),
      LocalDb.getNewReleases(),
    ]);
    if (mounted) {
      setState(() {
        _continueWatching = results[0] as List<Map<String, dynamic>>;
        _freeItems        = results[1] as List<CatalogItem>;
        _newReleases      = results[2] as List<CatalogItem>;
        _loadingExtras    = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _onSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = null;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final results = await ref.read(catalogProvider.notifier).search(query);
    setState(() {
      _searchResults = results;
      _searching = false;
    });
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
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 24,
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
                  // Watchlist icon
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.watchlist),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.bookmark_outlined,
                          color: AppColors.textPrimary, size: 24),
                    ),
                  ),
                  // Avatar
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.profile),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.primary.withOpacity(0.2),
                      child: Text(
                        user != null && user.phone.isNotEmpty
                            ? user.phone[0].toUpperCase()
                            : 'G',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Search Bar → navigates to SearchScreen with filters ──────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.search),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: AppColors.textMuted, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'Search movies, shows, genres...',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Sync strip ────────────────────────────────────────────────
            if (catalog.status == CatalogStatus.syncing)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 5),
                color: AppColors.primary.withOpacity(0.1),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
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
                          TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),

            // ── Main content ──────────────────────────────────────────────
            Expanded(
              child: _searchResults != null
                  ? _buildSearchResults()
                  : _buildMainContent(catalog),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RaddFlixBottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          if (i == 1) {
            Navigator.of(context).pushNamed(AppRoutes.watchlist);
          } else if (i == 2) {
            Navigator.of(context).pushNamed(AppRoutes.downloads);
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, color: AppColors.textMuted, size: 48),
            const SizedBox(height: 12),
            Text(
              'No results for "${_searchCtrl.text}"',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            ),
          ],
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
              onPressed: () {
                ref.read(catalogProvider.notifier).syncFromServer();
                _loadExtras();
              },
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // Pick featured item (highest rated movie)
    final allItems = [...catalog.movies, ...catalog.shows];
    final featured = allItems.isNotEmpty
        ? (allItems..sort((a, b) =>
            (b.rating ?? 0).compareTo(a.rating ?? 0))).first
        : null;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(catalogProvider.notifier).syncFromServer();
        await _loadExtras();
      },
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // ── Hero Banner ───────────────────────────────────────────────
          if (featured != null) _HeroBanner(item: featured),

          // ── Subscribe Banner (for non-subscribers) ───────────────────
          if (ref.watch(authProvider).user?.planName == 'free' ||
              ref.watch(authProvider).user == null)
            _SubscribeBanner(),

          // ── Continue Watching ─────────────────────────────────────────
          if (_continueWatching.isNotEmpty) ...[
            _SectionHeader(title: 'Continue Watching', icon: Icons.history_rounded),
            _ContinueWatchingRow(items: _continueWatching),
          ],

          // ── Free to Watch ─────────────────────────────────────────────
          if (_freeItems.isNotEmpty) ...[
            _SectionHeader(
              title: 'Free to Watch',
              icon: Icons.lock_open_rounded,
              badge: 'FREE',
            ),
            _HorizontalRow(items: _freeItems),
          ],

          // ── New Releases ───────────────────────────────────────────────
          if (_newReleases.isNotEmpty) ...[
            _SectionHeader(
              title: 'New Releases',
              icon: Icons.new_releases_rounded,
              badge: 'NEW',
            ),
            _HorizontalRow(items: _newReleases),
          ],

          // ── Movies ────────────────────────────────────────────────────
          if (catalog.movies.isNotEmpty) ...[
            _SectionHeader(
              title: 'Movies',
              count: catalog.movies.length,
              icon: Icons.movie_rounded,
              onSeeAll: catalog.movies.length > 6
                  ? () => _showAllGrid(context, 'Movies', catalog.movies)
                  : null,
            ),
            _HorizontalRow(items: catalog.movies),
          ],

          // ── TV Shows ──────────────────────────────────────────────────
          if (catalog.shows.isNotEmpty) ...[
            _SectionHeader(
              title: 'TV Shows',
              count: catalog.shows.length,
              icon: Icons.tv_rounded,
              onSeeAll: catalog.shows.length > 6
                  ? () => _showAllGrid(context, 'TV Shows', catalog.shows)
                  : null,
            ),
            _HorizontalRow(items: catalog.shows),
          ],
        ],
      ),
    );
  }

  void _showAllGrid(BuildContext context, String title, List<CatalogItem> items) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AllContentScreen(title: title, items: items),
      ),
    );
  }
}

// ── Hero Banner ────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final CatalogItem item;
  const _HeroBanner({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(
        AppRoutes.detail,
        arguments: item,
      ),
      child: Container(
        height: 260,
        margin: const EdgeInsets.fromLTRB(0, 4, 0, 0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster/backdrop
            _buildPosterImage(item),

            // Gradient
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x55000000),
                    Color(0xDD000000),
                    Color(0xFF08080E),
                  ],
                  stops: [0.0, 0.4, 0.75, 1.0],
                ),
              ),
            ),

            // Featured badge
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '✦ FEATURED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),

            // Bottom content
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (item.displayYear.isNotEmpty)
                        Text(
                          item.displayYear,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      if (item.displayRating.isNotEmpty) ...[
                        const Text(' · ',
                            style: TextStyle(color: Colors.white70)),
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 13),
                        Text(
                          ' ${item.displayRating}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (item.isMovie && item.fileId != null)
                        _HeroButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Watch Now',
                          onTap: () => Navigator.of(context).pushNamed(
                            AppRoutes.player,
                            arguments: {
                              'file_id': item.fileId!,
                              'title': item.title,
                            },
                          ),
                          filled: true,
                        ),
                      const SizedBox(width: 10),
                      _HeroButton(
                        icon: Icons.info_outline_rounded,
                        label: 'Details',
                        onTap: () => Navigator.of(context).pushNamed(
                          AppRoutes.detail,
                          arguments: item,
                        ),
                        filled: false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;
  const _HeroButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: filled
              ? null
              : Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildPosterImage(CatalogItem item) {
    final primary  = item.posterUrl;
    final fallback = item.posterJdUrl;
    if (primary != null && primary.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: primary,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(color: AppColors.surface),
        errorWidget: (_, __, ___) => fallback != null && fallback.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: fallback,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _posterFallback(),
              )
            : _posterFallback(),
      );
    }
    if (fallback != null && fallback.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: fallback,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _posterFallback(),
      );
    }
    return _posterFallback();
  }

  Widget _posterFallback() {
    return Container(
      color: AppColors.surface,
      child: const Icon(Icons.movie_rounded, color: AppColors.textMuted, size: 64),
    );
  }

}

// ── Subscribe Banner ───────────────────────────────────────────────────────────

class _SubscribeBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.subscription),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.2),
              AppColors.primary.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.star_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlock All Movies & Shows',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Subscribe from just PKR 149/month — data-free streaming',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Subscribe',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Continue Watching Row ──────────────────────────────────────────────────────

class _ContinueWatchingRow extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ContinueWatchingRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final item = items[i];
          final posMs = item['position_ms'] as int? ?? 0;
          final durMs = item['duration_ms'] as int? ?? 0;
          final progress = durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
          final title = item['title'] as String? ?? 'Unknown';
          final poster = item['poster_url'] as String?;
          final fileId = item['file_id'] as String? ?? '';

          return GestureDetector(
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.player,
              arguments: {'file_id': fileId, 'title': title},
            ),
            child: Container(
              width: 160,
              margin: EdgeInsets.only(right: i < items.length - 1 ? 10 : 0),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: poster != null
                        ? CachedNetworkImage(
                            imageUrl: poster,
                            fit: BoxFit.cover,
                            width: 160,
                            height: 120,
                            errorWidget: (_, __, ___) => Container(
                              color: AppColors.card,
                              width: 160,
                              height: 120,
                            ),
                          )
                        : Container(
                            color: AppColors.card,
                            width: 160,
                            height: 120,
                          ),
                  ),
                  // Gradient
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Progress bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                          child: LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary),
                            minHeight: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Play icon
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final String? badge;
  final IconData? icon;
  final VoidCallback? onSeeAll;

  const _SectionHeader({
    required this.title,
    this.count,
    this.badge,
    this.icon,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          if (badge != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          else if (count != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: const Text(
                'See All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Horizontal Row ─────────────────────────────────────────────────────────────

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

// ── All Content Grid Screen ────────────────────────────────────────────────────

class _AllContentScreen extends StatelessWidget {
  final String title;
  final List<CatalogItem> items;
  const _AllContentScreen({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.background,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2 / 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => ContentCard(item: items[i]),
      ),
    );
  }
}
