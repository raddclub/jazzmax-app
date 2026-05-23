import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/download/download_service.dart';
import '../core/download/download_quota_service.dart';
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
          : Column(
              children: [
                // Quota bar — always visible at top
                if (dl.quotaInfo != null)
                  _QuotaBar(quota: dl.quotaInfo!),

                // Inline error banner when a download is blocked by quota
                if (dl.quotaError != null)
                  _QuotaErrorBanner(
                    message: dl.quotaError!,
                    onDismiss: () =>
                        ref.read(downloadsProvider.notifier).clearQuotaError(),
                  ),

                Expanded(
                  child: dl.downloads.isEmpty
                      ? _buildEmpty()
                      : _buildList(dl),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_outlined,
              color: AppColors.textMuted, size: 64),
          SizedBox(height: 16),
          Text(
            'No downloads yet',
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
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
                await ref
                    .read(downloadsProvider.notifier)
                    .deleteDownload(item['file_id'] as String);
              }
            },
            onPlay: () {
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

// ─────────────────────────────────────────────────────────────────────────────
// Quota Bar — shows today's usage + live countdown to midnight reset
// ─────────────────────────────────────────────────────────────────────────────

class _QuotaBar extends StatefulWidget {
  final QuotaResult quota;
  const _QuotaBar({required this.quota});

  @override
  State<_QuotaBar> createState() => _QuotaBarState();
}

class _QuotaBarState extends State<_QuotaBar> {
  late Timer _timer;
  late Duration _timeLeft;

  @override
  void initState() {
    super.initState();
    _timeLeft = _calcTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _timeLeft = _calcTimeLeft());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Duration _calcTimeLeft() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }

  String _formatCountdown(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _planLabel(String planId) {
    switch (planId.toLowerCase()) {
      case 'basic':    return 'Basic Plan';
      case 'standard': return 'Standard Plan';
      case 'premium':  return 'Premium Plan';
      default:         return 'Free Plan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quota;

    // ── Unlimited (Premium) ───────────────────────────────────────────────
    if (q.isUnlimited) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.success.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.all_inclusive_rounded,
                color: AppColors.success, size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _planLabel(q.planId),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Unlimited downloads',
                  style: TextStyle(
                      color: AppColors.success, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ── Free plan (no downloads allowed) ─────────────────────────────────
    if (q.limit == 0) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: AppColors.warning.withOpacity(0.3), width: 1),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                color: AppColors.warning, size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Free Plan',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Upgrade to Basic or higher to download',
                    style:
                        TextStyle(color: AppColors.warning, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Basic / Standard — limited plan ──────────────────────────────────
    final used     = q.used;
    final limit    = q.limit;
    final fraction = (limit > 0 ? used / limit : 0.0).clamp(0.0, 1.0);
    final isMaxed  = used >= limit;
    final remaining = limit - used;

    Color barColor;
    if (fraction < 0.6) {
      barColor = AppColors.success;
    } else if (fraction < 0.85) {
      barColor = AppColors.warning;
    } else {
      barColor = AppColors.error;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMaxed
              ? AppColors.error.withOpacity(0.4)
              : AppColors.divider,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row: plan label + "used / limit today" ──────────────
          Row(
            children: [
              Icon(
                isMaxed
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
                color: isMaxed ? AppColors.error : AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _planLabel(q.planId),
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
              // e.g.  "3 / 5  today"
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$used',
                      style: TextStyle(
                        color: isMaxed
                            ? AppColors.error
                            : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextSpan(
                      text: ' / $limit',
                      style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w400),
                    ),
                    const TextSpan(
                      text: '  today',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Segmented progress bar ──────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.card,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),

          const SizedBox(height: 8),

          // ── Footer: slots left + countdown ─────────────────────────────
          Row(
            children: [
              if (!isMaxed)
                Text(
                  '$remaining download${remaining == 1 ? '' : 's'} remaining',
                  style: TextStyle(color: barColor, fontSize: 11),
                )
              else
                const Text(
                  'Limit reached — try again tomorrow',
                  style: TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              const Spacer(),
              const Icon(Icons.timer_outlined,
                  color: AppColors.textMuted, size: 13),
              const SizedBox(width: 4),
              Text(
                'Resets in ${_formatCountdown(_timeLeft)}',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline error banner — shows when a download is blocked by quota
// ─────────────────────────────────────────────────────────────────────────────

class _QuotaErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _QuotaErrorBanner(
      {required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: AppColors.error.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.block_rounded,
              color: AppColors.error, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                  color: AppColors.error, fontSize: 12, height: 1.4),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close_rounded,
                  color: AppColors.error, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Download tile
// ─────────────────────────────────────────────────────────────────────────────

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
    final title    = item['title_text'] as String? ?? 'Unknown';
    final poster   = item['poster_url'] as String?;
    final status   = item['status'] as String? ?? 'unknown';
    final progress =
        activeProgress ?? (item['progress'] as num? ?? 0).toDouble();
    final fileSize    = item['file_size'] as int? ?? 0;
    final isComplete  = status == 'completed';
    final isFailed    = status == 'failed';
    final isDownloading =
        status == 'downloading' || activeProgress != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Poster thumbnail
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
                      errorWidget: (_, __, ___) => _posterFallback(),
                    )
                  : _posterFallback(),
            ),
          ),

          // Title + status / progress
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

          // Play / delete buttons
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
