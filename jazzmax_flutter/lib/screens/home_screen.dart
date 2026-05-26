import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../core/constants.dart';
import '../core/theme/jazz_colors.dart';
import '../core/debug/debug_logger.dart';
import '../providers/auth_provider.dart';
import '../providers/catalog_provider.dart';
import '../models/catalog_item.dart';
import '../widgets/content_card.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/notification_banner.dart';
import '../core/services/notification_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _navIndex = 0;
  String _selectedCategory = 'All';
  final ScrollController _scroll = ScrollController();
  bool _scrolled = false;

  // Hidden debug panel — tap ZENO logo 5 times quickly
  int _debugTaps = 0;
  DateTime? _lastDebugTap;

  static const _categories = ['All', 'Movies', 'Shows', 'Dramas', 'Urdu', 'Punjabi', 'English'];

  @override
  void initState() {
    super.initState();
    DebugLogger.log('HOME', 'HomeScreen initState');
    _scroll.addListener(() {
      final now = _scroll.offset > 50;
      if (now != _scrolled) setState(() => _scrolled = now);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DebugLogger.log('HOME', 'Post-frame: calling catalogProvider.initialize()');
      ref.read(catalogProvider.notifier).initialize();
      NotificationService.instance.fetch();
    });
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _onLogoTap() {
    final now = DateTime.now();
    if (_lastDebugTap != null && now.difference(_lastDebugTap!).inSeconds > 2) {
      _debugTaps = 0;
    }
    _lastDebugTap = now;
    _debugTaps++;
    if (_debugTaps >= 5) {
      _debugTaps = 0;
      DebugLogger.log('DEBUG', 'Debug panel opened by user');
      _showDebugPanel();
    }
  }

  void _showDebugPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DebugPanel(),
    );
  }

  List<CatalogItem> _filtered(CatalogState s) {
    final all = [...s.movies, ...s.shows];
    switch (_selectedCategory) {
      case 'Movies':  return s.movies;
      case 'Shows':   return s.shows;
      case 'Dramas':  return all.where((i) => i.title.toLowerCase().contains('drama') || i.isShow).toList();
      case 'Urdu':    return all.where((i) => (i.language ?? '').toLowerCase().contains('urdu')).toList();
      case 'Punjabi': return all.where((i) => (i.language ?? '').toLowerCase().contains('punjabi')).toList();
      case 'English': return all.where((i) => (i.language ?? '').toLowerCase().contains('english')).toList();
      default:        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final user    = ref.watch(authProvider).user;

    // Log each rebuild state so we can track what the UI saw
    DebugLogger.log('HOME',
        'build — status=${catalog.status.name}  movies=${catalog.movies.length}  shows=${catalog.shows.length}  error=${catalog.error}');

    return Scaffold(
      backgroundColor: null,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(user),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => ref.read(catalogProvider.notifier).syncFromServer(),
        child: catalog.isEmpty && catalog.status == CatalogStatus.syncing
            ? _buildShimmer()
            : _buildContent(catalog),
      ),
      bottomNavigationBar: ZenoBottomNav(
        currentIndex: _navIndex,
        onTap: (i) {
          setState(() => _navIndex = i);
          if (i == 1) Navigator.of(context).pushNamed(AppRoutes.search);
          else if (i == 2) Navigator.of(context).pushNamed(AppRoutes.downloads);
          else if (i == 3) Navigator.of(context).pushNamed(AppRoutes.profile);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(dynamic user) {
    return AppBar(
      backgroundColor: _scrolled ? AppColors.surface.withOpacity(0.95) : Colors.transparent,
      elevation: 0,
      flexibleSpace: _scrolled
          ? null
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.background, Colors.transparent]),
              )),
      // Wrap logo with GestureDetector — tap 5 times to open debug panel
      title: GestureDetector(
        onTap: _onLogoTap,
        behavior: HitTestBehavior.opaque,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF9D5FFF), Color(0xFF7B2FFF), Color(0xFF2F8BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: const Text('ZENO', style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1.5,
          )),
        ),
      ),
      actions: [
        const NotificationBell(),
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 26),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.search),
        ),
        if (user != null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.profile),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: AppShadows.primary,
                ),
                child: Center(child: Text(
                  user.phone.isNotEmpty ? user.phone[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14))),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent(CatalogState catalog) {
    final filtered = _filtered(catalog);
    return CustomScrollView(
      controller: _scroll,
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 96)),

        if (catalog.status == CatalogStatus.syncing)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary))),
                SizedBox(width: 10),
                Text('Syncing catalog…', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ]),
            ),
          ),

        if (catalog.movies.isNotEmpty || catalog.shows.isNotEmpty)
          SliverToBoxAdapter(child: _HeroSpotlight(
            items: (catalog.movies.isNotEmpty ? catalog.movies : catalog.shows).take(5).toList(),
          ).animate().fadeIn(duration: 500.ms)),

        SliverToBoxAdapter(
          child: SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              itemCount: _categories.length,
              itemBuilder: (_, i) => _CategoryChip(
                label: _categories[i],
                isSelected: _selectedCategory == _categories[i],
                onTap: () => setState(() => _selectedCategory = _categories[i]),
              ).animate(delay: (i * 40).ms).fadeIn(duration: 300.ms)
                  .slideX(begin: 0.2, end: 0, duration: 300.ms, curve: AppCurves.standard),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 8)),

        if (catalog.trending.isNotEmpty)
          SliverToBoxAdapter(child: _ContentSection(
            title: '🔥 Trending Now',
            items: catalog.trending,
          ).animate().fadeIn(duration: 400.ms)),

        if (catalog.recentlyWatched.isNotEmpty)
          SliverToBoxAdapter(child: _ContentSection(
            title: 'Continue Watching',
            items: catalog.recentlyWatched,
            showProgress: true,
          )),

        if (_selectedCategory == 'All') ...[
          if (catalog.movies.isNotEmpty)
            SliverToBoxAdapter(child: _ContentSection(
              title: 'Movies',
              count: catalog.movies.length,
              items: catalog.movies,
            )),
          if (catalog.shows.isNotEmpty)
            SliverToBoxAdapter(child: _ContentSection(
              title: 'TV Shows & Dramas',
              count: catalog.shows.length,
              items: catalog.shows,
            )),
          // Show empty state with debug hint if nothing loaded
          if (catalog.movies.isEmpty && catalog.shows.isEmpty &&
              catalog.status == CatalogStatus.ready)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Column(children: [
                    const Icon(Icons.movie_filter_outlined,
                        color: AppColors.textMuted, size: 56),
                    const SizedBox(height: 16),
                    const Text('No content yet',
                        style: TextStyle(color: AppColors.textPrimary,
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(catalog.error ?? 'Pull down to retry sync',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    const Text('Tap ZENO logo 5× for debug info',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ]),
                ),
              ),
            ),
        ] else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: filtered.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(child: Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: Column(children: [
                        const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 48),
                        const SizedBox(height: 12),
                        Text('No $_selectedCategory content yet',
                            style: const TextStyle(color: AppColors.textMuted)),
                      ]),
                    )))
                : SliverGrid(
                    delegate: SliverChildBuilderDelegate((_, i) =>
                        ContentCard(item: filtered[i])
                            .animate(delay: (i * 30).ms).fadeIn(duration: 300.ms)
                            .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1),
                                duration: 300.ms, curve: AppCurves.standard),
                        childCount: filtered.length),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, childAspectRatio: 2/3,
                        crossAxisSpacing: 10, mainAxisSpacing: 10),
                  ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  Widget _buildShimmer() {
    return ListView(physics: const NeverScrollableScrollPhysics(), children: [
      const SizedBox(height: 96),
      Shimmer.fromColors(
        baseColor: AppColors.surface, highlightColor: AppColors.surfaceHigh,
        child: Container(height: 220, margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg)))),
      const SizedBox(height: 16),
      SizedBox(height: 180,
        child: ListView.builder(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 5, itemBuilder: (_, __) =>
              Padding(padding: const EdgeInsets.only(right: 10),
                child: Shimmer.fromColors(baseColor: AppColors.surface,
                  highlightColor: AppColors.surfaceHigh,
                  child: Container(width: 120, decoration: BoxDecoration(color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.sm))))))),
    ]);
  }
}

// ── Debug Panel ───────────────────────────────────────────────────────────────
class _DebugPanel extends StatefulWidget {
  const _DebugPanel();
  @override
  State<_DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends State<_DebugPanel> {
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final logPath = DebugLogger.getLogPath();
    final lastLines = DebugLogger.getLastLines(80);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A14),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: AppColors.primary, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(children: [
              const Icon(Icons.bug_report_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              const Text('ZENO Debug Log',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
              const Spacer(),
              // Copy path button
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Color(0xFF9090B0), size: 20),
                tooltip: 'Copy log path',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: logPath));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Log path copied to clipboard'),
                        duration: Duration(seconds: 2)));
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF9090B0), size: 22),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // File path
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('📁 $logPath',
                style: const TextStyle(color: Color(0xFF6060A0), fontSize: 10),
                overflow: TextOverflow.ellipsis),
          ),
          const Divider(color: Color(0xFF1A1A2E), height: 1),
          // Log content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                lastLines,
                style: const TextStyle(
                    color: Color(0xFFB0B0D0),
                    fontFamily: 'monospace',
                    fontSize: 10,
                    height: 1.5),
              ),
            ),
          ),
          const Divider(color: Color(0xFF1A1A2E), height: 1),
          // Action buttons
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
                12 + MediaQuery.of(context).padding.bottom),
            child: Row(children: [
              // Copy logs button
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_all_rounded, size: 16),
                  label: const Text('Copy Logs'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF303050)),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: lastLines));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Log copied to clipboard'),
                          duration: Duration(seconds: 2)));
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Share button
              Expanded(
                child: ElevatedButton.icon(
                  icon: _sharing
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2,
                              color: Colors.white))
                      : const Icon(Icons.share_rounded, size: 16),
                  label: Text(_sharing ? 'Sharing…' : 'Share File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _sharing ? null : () async {
                    setState(() => _sharing = true);
                    await DebugLogger.shareLogs();
                    if (mounted) setState(() => _sharing = false);
                  },
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Hero Spotlight ────────────────────────────────────────────────────────────
class _HeroSpotlight extends StatefulWidget {
  final List<CatalogItem> items;
  const _HeroSpotlight({required this.items});
  @override
  State<_HeroSpotlight> createState() => _HeroSpotlightState();
}

class _HeroSpotlightState extends State<_HeroSpotlight> {
  final PageController _ctrl = PageController();
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _autoScroll();
  }

  void _autoScroll() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      final next = (_current + 1) % widget.items.length;
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic);
      _autoScroll();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 220,
        child: PageView.builder(
          controller: _ctrl,
          itemCount: widget.items.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => _HeroCard(item: widget.items[i]),
        ),
      ),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(
        widget.items.length,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: _current == i ? 18 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: _current == i ? AppColors.primary : AppColors.textMuted.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3)),
        ),
      )),
    ]);
  }
}

class _HeroCard extends StatelessWidget {
  final CatalogItem item;
  const _HeroCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        DebugLogger.logUi('HeroCard', 'Tapped: ${item.title} (id=${item.id})');
        Navigator.of(context).pushNamed(AppRoutes.showDetail, arguments: item);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Stack(fit: StackFit.expand, children: [
            item.posterUrl != null
                ? CachedNetworkImage(imageUrl: item.posterUrl!, fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppColors.card,
                        child: const Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 48)))
                : Container(color: AppColors.card),
            Builder(builder: (ctx) => DecoratedBox(decoration: BoxDecoration(gradient: ctx.jazzHeroGradient))),
            Positioned(bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.title, style: const TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800,
                      letterSpacing: -0.3, shadows: [Shadow(color: Colors.black, blurRadius: 8)])),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(AppRadius.round),
                          boxShadow: AppShadows.primary),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 4),
                        Text('Watch Now', style: TextStyle(color: Colors.white,
                            fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    if (item.displayRating.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black38,
                            borderRadius: BorderRadius.circular(AppRadius.round)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                          const SizedBox(width: 3),
                          Text(item.displayRating, style: const TextStyle(
                              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
                ]),
              )),
          ]),
        ),
      ),
    );
  }
}

// ── Content Section ───────────────────────────────────────────────────────────
class _ContentSection extends StatelessWidget {
  final String title;
  final int? count;
  final List<CatalogItem> items;
  final bool showProgress;
  const _ContentSection({required this.title, this.count, required this.items, this.showProgress = false});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary,
              fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.round),
                  border: Border.all(color: AppColors.glassBorder)),
              child: Text(count.toString(),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: () {
              String? filter;
              if (title == "Movies") filter = "Movies";
              else if (title.contains("Show") || title.contains("Drama")) filter = "Shows";
              Navigator.of(context).pushNamed(AppRoutes.search,
                  arguments: {"initialFilter": filter});
            },
            child: const Text("See all", style: TextStyle(color: AppColors.primary, fontSize: 13))),
        ]),
      ),
      SizedBox(
        height: 190,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(right: i < items.length - 1 ? 10 : 0),
            child: SizedBox(width: 126,
                child: ContentCard(item: items[i], showProgress: showProgress,
                    progress: showProgress ? (items[i].watchProgress ?? 0.5) : null))
                .animate(delay: (i * 30).ms).fadeIn(duration: 300.ms)
                .slideX(begin: 0.1, end: 0, duration: 300.ms, curve: AppCurves.standard),
          ),
        ),
      ),
    ]);
  }
}

// ── Category Chip ─────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _CategoryChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.round),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.glassBorder, width: 1),
          boxShadow: isSelected ? AppShadows.primary : null,
        ),
        child: Text(label, style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textMuted,
          fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal)),
      ),
    );
  }
}
