import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/download/download_service.dart';
import '../providers/downloads_provider.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadsProvider.notifier).loadDownloads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dl = ref.watch(downloadsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Downloads'),
        backgroundColor: AppColors.background,
      ),
      body: dl.loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : dl.downloads.isEmpty
              ? _buildEmpty()
              : _buildList(dl),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_outlined,
              color: AppColors.textMuted, size: 64),
          const SizedBox(height: 16),
          const Text(
            'No downloads yet',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Download movies to watch without streaming',
            style:
                TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildList(DownloadsState dl) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () =>
          ref.read(downloadsProvider.notifier).loadDownloads(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: dl.downloads.length,
        itemBuilder: (_, i) {
          final item = dl.downloads[i];
          return _DownloadTile(
            item: item,
            activeProgress: dl.isDownloading(item['file_id'] as String)
                ? dl.progressOf(item['file_id'] as String)
                : null,
            onDelete: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('Delete Download?',
                      style:
                          TextStyle(color: AppColors.textPrimary)),
                  content: Text(
                    'Delete "${item['title_text']}"?',
                    style:
                        const TextStyle(color: AppColors.textMuted),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel',
                          style: TextStyle(
                              color: AppColors.textMuted)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete',
                          style:
                              TextStyle(color: AppColors.error)),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await ref.read(downloadsProvider.notifier).deleteDownload(
                    item['file_id'] as String);
              }
            },
            onPlay: () {
              // Play from local file
              final localPath = item['local_path'] as String?;
              if (localPath != null && item['status'] == 'completed') {
                Navigator.of(context).pushNamed(
                  AppRoutes.player,
                  arguments: {
                    'file_id': item['file_id'] as String,
                    'title': item['title_text'] as String? ?? '',
                    'local_path': localPath,
                  },
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final double? activeProgress;
  final VoidCallback onDelete;
  final VoidCallback onPlay;

  const _DownloadTile({
    required this.item,
    this.activeProgress,
    required this.onDelete,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final title = item['title_text'] as String? ?? 'Unknown';
    final poster = item['poster_url'] as String?;
    final status = item['status'] as String? ?? 'unknown';
    final progress = activeProgress ?? (item['progress'] as num? ?? 0).toDouble();
    final fileSize = item['file_size'] as int? ?? 0;
    final isComplete = status == 'completed';
    final isFailed = status == 'failed';
    final isDownloading = status == 'downloading' || activeProgress != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Poster
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
            child: SizedBox(
              width: 72,
              height: 90,
              child: poster != null && poster.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: poster,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _posterFallback(),
                    )
                  : _posterFallback(),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (isComplete)
                    Text(
                      DownloadService.formatFileSize(fileSize),
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  if (isFailed)
                    const Text('Download failed',
                        style: TextStyle(
                            color: AppColors.error, fontSize: 12)),
                  if (isDownloading) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 3,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Actions
          Column(
            children: [
              if (isComplete)
                IconButton(
                  icon: const Icon(Icons.play_circle_filled_rounded,
                      color: AppColors.primary, size: 28),
                  onPressed: onPlay,
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.textMuted, size: 22),
                onPressed: isDownloading ? null : onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: AppColors.card,
      child: const Icon(Icons.movie_outlined,
          color: AppColors.textMuted, size: 28),
    );
  }
}
