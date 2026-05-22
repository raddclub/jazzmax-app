import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../models/catalog_item.dart';

class ContentCard extends StatelessWidget {
  final CatalogItem item;
  final VoidCallback? onTap;

  const ContentCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () => _onTap(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Poster image ───────────────────────────────────────────
            item.posterUrl != null && item.posterUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.posterUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textMuted),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _PosterFallback(item: item),
                  )
                : _PosterFallback(item: item),

            // ── Gradient overlay at bottom ─────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 24, 8, 8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),
              ),
            ),

            // ── Free badge ─────────────────────────────────────────────
            if (item.isFree)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'FREE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // ── Rating badge ───────────────────────────────────────────
            if (item.rating != null && item.rating! > 0)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 10),
                      const SizedBox(width: 2),
                      Text(
                        item.displayRating,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context) {
    if (item.isMovie && item.fileId != null) {
      Navigator.of(context).pushNamed(
        AppRoutes.player,
        arguments: {
          'file_id': item.fileId!,
          'title': item.title,
        },
      );
    } else {
      // Show detail bottom sheet for movies without fileId or for shows
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _DetailSheet(item: item),
      );
    }
  }
}

class _PosterFallback extends StatelessWidget {
  final CatalogItem item;
  const _PosterFallback({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.isShow ? Icons.tv_outlined : Icons.movie_outlined,
            color: AppColors.textMuted,
            size: 32,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final CatalogItem item;
  const _DetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (item.displayYear.isNotEmpty)
                Text(item.displayYear,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 13)),
              if (item.displayYear.isNotEmpty && item.displayRating.isNotEmpty)
                const Text(' · ',
                    style: TextStyle(color: AppColors.textMuted)),
              if (item.displayRating.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 14),
                    Text(item.displayRating,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ],
                ),
            ],
          ),
          if (item.description != null && item.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              item.description!,
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 13, height: 1.5),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: item.fileId != null
                ? () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamed(
                      AppRoutes.player,
                      arguments: {
                        'file_id': item.fileId!,
                        'title': item.title,
                      },
                    );
                  }
                : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Watch Now'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
