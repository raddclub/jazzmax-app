import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../core/constants.dart';
import '../core/db/local_db.dart';

/// Local Media Player screen — lets users browse and play their OWN video files
/// from device storage using JazzMAX's player.
/// Supports ALL video/audio formats (mp4, mkv, avi, mov, ts, wmv, flv, rmvb, ea3x, etc.)
class LocalMediaScreen extends StatefulWidget {
  const LocalMediaScreen({super.key});

  @override
  State<LocalMediaScreen> createState() => _LocalMediaScreenState();
}

class _LocalMediaScreenState extends State<LocalMediaScreen> {
  List<_LocalFile> _recentFiles = [];
  bool _loading = false;

  // Common Android video directories to scan
  static const List<String> _scanDirs = [
    '/sdcard/Download',
    '/sdcard/Downloads',
    '/sdcard/DCIM',
    '/sdcard/Movies',
    '/sdcard/Videos',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/Movies',
    '/storage/emulated/0/Videos',
    '/storage/emulated/0/DCIM',
  ];

  static const List<String> _videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'm4v', 'webm',
    'ts', 'm2ts', 'mts', 'rmvb', 'rm', 'mpeg', 'mpg', '3gp',
    'f4v', 'h264', 'h265', 'hevc', 'divx', 'xvid',
    // Audio formats
    'mp3', 'aac', 'flac', 'ogg', 'wav', 'm4a', 'opus',
    // Hardcore formats
    'ea3x', 'dts', 'eac3', 'ac3', 'truehd',
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    setState(() => _loading = true);
    try {
      final rows = await LocalDb.getLocalMediaHistory();
      final files = <_LocalFile>[];
      for (final row in rows) {
        final path = row['file_path'] as String? ?? '';
        if (File(path).existsSync()) {
          files.add(_LocalFile(
            path: path,
            name: p.basename(path),
            size: _parseSize(row['file_size']),
            playedAt: row['played_at'] as int? ?? 0,
          ));
        }
      }
      if (mounted) setState(() { _recentFiles = files; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _parseSize(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    return int.tryParse(val.toString()) ?? 0;
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _videoExtensions,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        _openFile(path);
      }
    } catch (e) {
      _showError('Could not open file picker: $e');
    }
  }

  Future<void> _scanDirectory() async {
    setState(() => _loading = true);
    final found = <_LocalFile>[];

    for (final dirPath in _scanDirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      try {
        final entries = dir.listSync(recursive: false);
        for (final entry in entries) {
          if (entry is File) {
            final ext = p.extension(entry.path).toLowerCase().replaceFirst('.', '');
            if (_videoExtensions.contains(ext)) {
              final stat = entry.statSync();
              found.add(_LocalFile(
                path: entry.path,
                name: p.basename(entry.path),
                size: stat.size,
                playedAt: 0,
              ));
            }
          }
        }
      } catch (_) {}
    }

    // Sort by name
    found.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (mounted) {
      setState(() => _loading = false);
      if (found.isEmpty) {
        _showError('No video files found in common folders.\nUse "Browse Files" to pick a file manually.');
      } else {
        _showScanResults(found);
      }
    }
  }

  void _showScanResults(List<_LocalFile> files) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    '${files.length} videos found',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: files.length,
                itemBuilder: (_, i) => _FileListTile(
                  file: files[i],
                  onTap: () {
                    Navigator.pop(context);
                    _openFile(files[i].path);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFile(String path) async {
    final name = p.basename(path);
    final file = File(path);
    int size = 0;
    try { size = file.lengthSync(); } catch (_) {}

    // Save to history
    await LocalDb.saveLocalMediaHistory(path: path, fileSize: size);
    _loadRecentFiles();

    if (!mounted) return;
    Navigator.of(context).pushNamed(
      AppRoutes.player,
      arguments: {
        'file_id': path, // use path as fileId for local files
        'title': name,
        'local_path': path,
      },
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _removeFromHistory(String path) async {
    await LocalDb.deleteLocalMediaHistory(path);
    _loadRecentFiles();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open_rounded),
            tooltip: 'Scan common folders',
            onPressed: _scanDirectory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Browse button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.video_file_rounded),
              label: const Text('Browse & Pick a Video File'),
              onPressed: _pickFile,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ),

          // Format info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Supports: MP4, MKV, AVI, MOV, TS, EAC3, DTS, FLAC and all major formats',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Recent files section
          if (_loading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            )
          else if (_recentFiles.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.video_library_outlined,
                        color: AppColors.textMuted, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'No recent files',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick a video file to play it\nin JazzMAX player',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Scan Downloads Folder'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: _scanDirectory,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Recently Played',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _recentFiles.length,
                      itemBuilder: (_, i) => Dismissible(
                        key: Key(_recentFiles[i].path),
                        background: Container(
                          color: Colors.red.shade800,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeFromHistory(_recentFiles[i].path),
                        child: _FileListTile(
                          file: _recentFiles[i],
                          showDate: true,
                          onTap: () => _openFile(_recentFiles[i].path),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LocalFile {
  final String path;
  final String name;
  final int size;
  final int playedAt;

  const _LocalFile({
    required this.path,
    required this.name,
    required this.size,
    required this.playedAt,
  });
}

class _FileListTile extends StatelessWidget {
  final _LocalFile file;
  final VoidCallback onTap;
  final bool showDate;

  const _FileListTile({
    required this.file,
    required this.onTap,
    this.showDate = false,
  });

  String _formatSize(int bytes) {
    if (bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _ext() {
    final ext = p.extension(file.name).replaceFirst('.', '').toUpperCase();
    return ext.isEmpty ? 'VIDEO' : ext;
  }

  Color _extColor() {
    final ext = _ext();
    if (['MKV', 'EAC3', 'DTS', 'FLAC'].contains(ext)) return Colors.purple;
    if (['MP4', 'M4V', 'MOV'].contains(ext)) return Colors.blue;
    if (['AVI', 'DIVX', 'XVID'].contains(ext)) return Colors.orange;
    if (['MP3', 'AAC', 'WAV', 'OGG'].contains(ext)) return Colors.green;
    return AppColors.primary;
  }

  String _dateLabel() {
    if (file.playedAt == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(file.playedAt);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _extColor().withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            _ext().length > 4 ? _ext().substring(0, 4) : _ext(),
            style: TextStyle(
              color: _extColor(),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
      title: Text(
        file.name,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          if (file.size > 0) _formatSize(file.size),
          if (showDate && file.playedAt > 0) _dateLabel(),
        ].join(' · '),
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
      ),
      trailing: const Icon(Icons.play_circle_outline_rounded, color: AppColors.primary, size: 28),
      onTap: onTap,
    );
  }
}
