import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/db/local_db.dart';
import '../models/catalog_item.dart';
import '../providers/watchlist_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/loading_overlay.dart';

class DetailScreen extends ConsumerStatefulWidget {
  final CatalogItem item;
  const DetailScreen({super.key, required this.item});

  @override
  ConsumerState<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends ConsumerState<DetailScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  List<Map<String, dynamic>> _episodes = [];
  int _selectedSeason = 1;
  bool _loadingEpisodes = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isShow) {
      _loadingEpisodes = true;
      _loadEpisodes();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(watchlistProvider.notifier)
          .checkWatchlist(widget.item.id);
    });
  }

  Future<void> _loadEpisodes() async {
    final eps = await LocalDb.getEpisodes(widget.item.id);
    if (mounted) {
      setState(() {
        _episodes = eps;
        _loadingEpisodes = false;
        final seasons = eps.map((e) => e['season'] as int? ?? 1).toSet().toList()
          ..sort();
        if (seasons.isNotEmpty) _selectedSeason = seasons.first;
      });
    }
  }

  List<int> get _seasons {
    final s = _episodes.map((e) => e['season'] as int? ?? 1).toSet().toList()
      ..sort();
    return s;
  }

  List<Map<String, dynamic>> get _currentEpisodes =>
      _episodes.where((e) => (e['season'] as int? ?? 1) == _selectedSeason).toList();

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _play(String fileId, String title) {
    Navigator.of(context).pushNamed(
      AppRoutes.player,
      arguments: {'file_id': fileId, 'title': title},
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final wl = ref.watch(watchlistProvider);
    final user = ref.watch(authProvider).user;
    final isInWatchlist = wl.watchlistIds.contains(item.id);

    List<String> genreList = [];
    if (item.genres != null && item.genres!.isNotEmpty) {
      try {
        final decoded = jsonDecode(item.genres!);
        if (decoded is List) genreList = decoded.cast<String>();
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Backdrop hero ───────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.background,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: wl.loading
                    ? null
                    : () {
                        if (user == null) {
                          _promptLogin();
                          return;
                        }
                        ref
                            .read(watchlistProvider.notifier)
                            .toggle(item);
                      },
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isInWatchlist
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_add_outlined,
                    color: isInWatchlist ? AppColors.primary : Colors.white,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildDetailPoster(item),
                  // Gradient overlay
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Color(0x99000000),
                          Color(0xFF08080E),
                        ],
                        stops: [0.0, 0.4, 0.75, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content ─────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Meta row
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (item.displayYear.isNotEmpty)
                        _MetaChip(item.displayYear),
                      if (item.displayRating.isNotEmpty)
                        _MetaChip(
                          '★ ${item.displayRating}',
                          color: Colors.amber,
                        ),
                      if (item.isFree)
                        _MetaChip('FREE', color: AppColors.success),
                      _MetaChip(
                        item.isMovie ? 'Movie' : 'TV Show',
                        color: AppColors.primary,
                      ),
                    ],
                  ),

                  // Genres
                  if (genreList.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: genreList
                          .map((g) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                      Border.all(color: AppColors.divider),
                                ),
                                child: Text(
                                  g,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Watch Now button
                  if (item.isMovie && item.fileId != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _play(item.fileId!, item.title),
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text('Watch Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ),
                  if (item.isMovie && item.fileId == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Text('Not available yet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.surface,
                          minimumSize: const Size(double.infinity, 52),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Add to Watchlist button (outline)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: wl.loading
                          ? null
                          : () {
                              if (user == null) {
                                _promptLogin();
                                return;
                              }
                              ref
                                  .read(watchlistProvider.notifier)
                                  .toggle(item);
                            },
                      icon: Icon(
                        isInWatchlist
                            ? Icons.bookmark_remove_outlined
                            : Icons.bookmark_add_outlined,
                        size: 20,
                      ),
                      label: Text(
                        isInWatchlist
                            ? 'Remove from Watchlist'
                            : 'Add to Watchlist',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isInWatchlist
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        side: BorderSide(
                          color: isInWatchlist
                              ? AppColors.primary
                              : AppColors.divider,
                        ),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Description
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const Text(
                      'About',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _ExpandableText(item.description!),
                  ],

                  // TV Show episodes
                  if (item.isShow) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Episodes',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingEpisodes)
                      const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary),
                        ),
                      )
                    else if (_episodes.isEmpty)
                      const Text(
                        'No episodes available yet',
                        style: TextStyle(color: AppColors.textMuted),
                      )
                    else ...[
                      // Season selector
                      if (_seasons.length > 1)
                        SizedBox(
                          height: 38,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _seasons.length,
                            itemBuilder: (_, i) {
                              final s = _seasons[i];
                              final selected = s == _selectedSeason;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedSeason = s),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.surface,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Season $s',
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Episode list
                      ..._currentEpisodes.map((ep) => _EpisodeTile(
                            episode: ep,
                            showTitle: item.title,
                            onPlay: _play,
                          )),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _promptLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sign in to use Watchlist'),
        action: SnackBarAction(
          label: 'Sign In',
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.login),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final Color? color;
  const _MetaChip(this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: color ?? AppColors.textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}


Widget _buildDetailPoster(CatalogItem item) {
  final primary = item.posterUrl;
  final fallback = item.posterJdUrl;
  if (primary != null && primary.isNotEmpty) {
    return CachedNetworkImage(
      imageUrl: primary,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => fallback != null && fallback.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: fallback,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _BackdropFallback(item: item),
            )
          : _BackdropFallback(item: item),
    );
  }
  if (fallback != null && fallback.isNotEmpty) {
    return CachedNetworkImage(
      imageUrl: fallback,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => _BackdropFallback(item: item),
    );
  }
  return _BackdropFallback(item: item);
}


class _BackdropFallback extends StatelessWidget {
  final CatalogItem item;
  const _BackdropFallback({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.isShow ? Icons.tv_rounded : Icons.movie_rounded,
            color: AppColors.textMuted,
            size: 64,
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;
  const _ExpandableText(this.text);

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : 4,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Text(
            _expanded ? 'Show less' : 'Read more',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Map<String, dynamic> episode;
  final String showTitle;
  final void Function(String fileId, String title) onPlay;
  const _EpisodeTile({
    required this.episode,
    required this.showTitle,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final ep = episode['episode'] as int? ?? 0;
    final season = episode['season'] as int? ?? 1;
    final label = episode['label'] as String? ?? 'S${season.toString().padLeft(2, '0')}E${ep.toString().padLeft(2, '0')}';
    final fileId = episode['file_id']?.toString();
    final isFree = (episode['is_free'] as int? ?? 0) == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              ep.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: isFree
            ? const Text('Free', style: TextStyle(color: AppColors.success, fontSize: 11))
            : null,
        trailing: fileId != null
            ? GestureDetector(
                onTap: () => onPlay(fileId, '$showTitle — $label'),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 20),
                ),
              )
            : const Icon(Icons.lock_outline,
                color: AppColors.textMuted, size: 20),
      ),
    );
  }
}
