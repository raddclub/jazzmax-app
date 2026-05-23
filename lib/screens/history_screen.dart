import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants.dart';
import '../core/db/local_db.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await LocalDb.getWatchHistory();
    if (mounted) {
      setState(() {
        _history = items;
        _loading = false;
      });
    }
  }

  Future<void> _delete(String fileId) async {
    await LocalDb.clearPosition(fileId);
    setState(() => _history.removeWhere((h) => h['file_id'] == fileId));
  }

  String _formatProgress(int posMs, int durMs) {
    if (durMs <= 0) return '';
    final pct = (posMs / durMs * 100).round();
    return '$pct% watched';
  }

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Watch History'),
        backgroundColor: AppColors.background,
        actions: [
          if (_history.isNotEmpty)
            TextButton(
              onPressed: _confirmClearAll,
              child: const Text(
                'Clear All',
                style: TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        color: AppColors.textMuted,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No watch history yet',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Movies and shows you watch will appear here',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _history.length,
                  itemBuilder: (_, i) {
                    final h = _history[i];
                    final posMs = h['position_ms'] as int? ?? 0;
                    final durMs = h['duration_ms'] as int? ?? 0;
                    final fileId = h['file_id'] as String? ?? '';
                    final title = h['title'] as String? ?? 'Unknown';
                    final poster = h['poster_url'] as String?;
                    final progress =
                        durMs > 0 ? posMs / durMs : 0.0;

                    return Dismissible(
                      key: Key(fileId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_outline,
                            color: AppColors.error),
                      ),
                      onDismissed: (_) => _delete(fileId),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 56,
                              height: 80,
                              child: poster != null
                                  ? CachedNetworkImage(
                                      imageUrl: poster,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppColors.card,
                                        child: const Icon(Icons.movie_outlined,
                                            color: AppColors.textMuted),
                                      ),
                                    )
                                  : Container(
                                      color: AppColors.card,
                                      child: const Icon(Icons.movie_outlined,
                                          color: AppColors.textMuted),
                                    ),
                            ),
                          ),
                          title: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              if (durMs > 0) ...[
                                Text(
                                  '${_formatDuration(posMs)} / ${_formatDuration(durMs)}',
                                  style: const TextStyle(
                                      color: AppColors.textMuted, fontSize: 11),
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: progress.clamp(0.0, 1.0),
                                    backgroundColor: AppColors.card,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            AppColors.primary),
                                    minHeight: 3,
                                  ),
                                ),
                              ],
                              if (_formatProgress(posMs, durMs).isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatProgress(posMs, durMs),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: GestureDetector(
                            onTap: () => Navigator.of(context).pushNamed(
                              AppRoutes.player,
                              arguments: {
                                'file_id': fileId,
                                'title': title,
                              },
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Clear History',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Remove all watch history?',
            style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear All',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true) {
      await LocalDb.clearAllPositions();
      setState(() => _history = []);
    }
  }
}
