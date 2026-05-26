import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/constants.dart';
import '../core/api/api_client.dart';

class AdminQueueScreen extends StatefulWidget {
  const AdminQueueScreen({super.key});
  @override
  State<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends State<AdminQueueScreen> {
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res  = await ApiClient.instance.get(ApiPaths.adminQueue);
      final data = res.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _jobs    = List<Map<String, dynamic>>.from(data['jobs'] as List? ?? []);
          _loading = false;
          _error   = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'done':       return AppColors.success;
      case 'error':
      case 'failed':     return AppColors.error;
      case 'processing':
      case 'downloading':
      case 'uploading':  return AppColors.info;
      case 'queued':     return AppColors.warning;
      case 'cancelled':  return AppColors.textMuted;
      default:           return AppColors.textMuted;
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'done':        return Icons.check_circle_rounded;
      case 'error':
      case 'failed':      return Icons.error_rounded;
      case 'processing':
      case 'downloading': return Icons.download_rounded;
      case 'uploading':   return Icons.cloud_upload_rounded;
      case 'queued':      return Icons.schedule_rounded;
      case 'cancelled':   return Icons.cancel_rounded;
      default:            return Icons.circle_outlined;
    }
  }

  String _siteLabel(String? site) {
    const labels = {
      'auto':       'Auto',
      'direct':     'Direct URL',
      'upload':     'Upload',
      'vegamovies': 'VegaMovies',
      'katmoviehd': 'KatMovieHD',
      'ssrmovies':  'SSRMovies',
      'rogmovies':  'RogMovies',
    };
    return labels[site] ?? (site ?? '?');
  }

  String _relativeTime(dynamic ts) {
    if (ts == null) return '';
    final t  = DateTime.fromMillisecondsSinceEpoch((ts as int) * 1000);
    final d  = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24)   return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final active   = _jobs.where((j) => !['done','error','failed','cancelled'].contains(j['status'])).toList();
    final finished = _jobs.where((j) =>  ['done','error','failed','cancelled'].contains(j['status'])).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App bar
          SliverAppBar(
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text('Server Downloads',
                style: TextStyle(color: AppColors.textPrimary,
                    fontSize: 18, fontWeight: FontWeight.w700)),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.textMuted, size: 22),
                onPressed: _load,
              ),
              const SizedBox(width: 8),
            ],
          ),

          if (_loading && _jobs.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary)),
            )

          else if (_error != null && _jobs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.cloud_off_rounded,
                      color: AppColors.textMuted, size: 48),
                  const SizedBox(height: 12),
                  const Text('Could not reach server',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(_error!, style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  TextButton(onPressed: _load,
                      child: const Text('Retry',
                          style: TextStyle(color: AppColors.primary))),
                ]),
              ),
            )

          else if (_jobs.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.download_done_rounded,
                    color: AppColors.textMuted, size: 52),
                SizedBox(height: 12),
                Text('No download jobs yet',
                    style: TextStyle(color: AppColors.textMuted,
                        fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('Use the admin panel to start a download.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ])),
            )

          else ...[
            // Stats bar
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Stat(label: 'Active',
                        value: active.length.toString(),
                        color: AppColors.info),
                    _Stat(label: 'Done',
                        value: finished.where((j) => j['status'] == 'done').length.toString(),
                        color: AppColors.success),
                    _Stat(label: 'Failed',
                        value: finished.where((j) => ['error','failed'].contains(j['status'])).length.toString(),
                        color: AppColors.error),
                    _Stat(label: 'Total',
                        value: _jobs.length.toString(),
                        color: AppColors.textMuted),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),
            ),

            // Active jobs
            if (active.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text('ACTIVE', style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _JobCard(
                    job: active[i],
                    statusColor: _statusColor(active[i]['status'] as String?),
                    statusIcon: _statusIcon(active[i]['status'] as String?),
                    siteLabel: _siteLabel(active[i]['site'] as String?),
                    relTime: _relativeTime(active[i]['updated_at']),
                  ).animate(delay: Duration(milliseconds: i * 40))
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.1, end: 0, duration: 300.ms),
                  childCount: active.length,
                ),
              ),
            ],

            // Finished jobs
            if (finished.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('RECENT', style: TextStyle(
                      color: AppColors.textMuted, fontSize: 11,
                      fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _JobCard(
                    job: finished[i],
                    statusColor: _statusColor(finished[i]['status'] as String?),
                    statusIcon: _statusIcon(finished[i]['status'] as String?),
                    siteLabel: _siteLabel(finished[i]['site'] as String?),
                    relTime: _relativeTime(finished[i]['updated_at']),
                    dimmed: true,
                  ).animate(delay: Duration(milliseconds: i * 30))
                      .fadeIn(duration: 200.ms),
                  childCount: finished.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(
          color: color, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(
          color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final Color statusColor;
  final IconData statusIcon;
  final String siteLabel, relTime;
  final bool dimmed;

  const _JobCard({
    required this.job,
    required this.statusColor,
    required this.statusIcon,
    required this.siteLabel,
    required this.relTime,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final status   = job['status'] as String? ?? '';
    final progress = (job['progress'] as num?)?.toDouble() ?? 0.0;
    final message  = job['message'] as String? ?? '';
    final movie    = job['movie']   as String? ?? 'Unknown';
    final isActive = !['done','error','failed','cancelled'].contains(status);

    return Opacity(
      opacity: dimmed ? 0.65 : 1.0,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isActive
                ? statusColor.withOpacity(0.35)
                : AppColors.glassBorder,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withOpacity(0.15),
              ),
              child: Icon(statusIcon, color: statusColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(movie, style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(status.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 9,
                            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  ),
                  const SizedBox(width: 6),
                  Text(siteLabel,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const Spacer(),
                  Text(relTime,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ]),
              ]),
            ),
          ]),

          // Progress bar (for active jobs)
          if (isActive && progress > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress / 100,
                backgroundColor: AppColors.glassBorder,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text('${progress.toStringAsFixed(1)}%',
                style: TextStyle(color: statusColor,
                    fontSize: 10, fontWeight: FontWeight.w600)),
          ],

          // Indeterminate for queued
          if (status == 'queued') ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: const LinearProgressIndicator(
                backgroundColor: AppColors.glassBorder,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
                minHeight: 4,
              ),
            ),
          ],

          // Message
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(message,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }
}
