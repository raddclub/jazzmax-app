import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../core/db/local_db.dart';
import '../core/security/vault_service.dart';
import '../providers/vault_provider.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen>
    with WidgetsBindingObserver {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _gridView = true;
  bool _importing = false;
  int _importTotal = 0;
  int _importDone = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadItems();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app goes background, lock vault — next time user opens vault tab
    // they'll hit the lock screen
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // VaultNotifier already handles this via its own observer,
      // but pop this screen so next vault entry goes through lock screen
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  Future<void> _loadItems() async {
    setState(() => _loading = true);
    final items = await LocalDb.getVaultItems();
    if (mounted) setState(() { _items = items; _loading = false; });
  }

  Future<void> _pickAndImport() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open file picker'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (result == null || result.files.isEmpty) return;

    final files = result.files
        .where((f) => f.path != null)
        .map((f) => File(f.path!))
        .toList();

    if (files.isEmpty) return;

    setState(() {
      _importing = true;
      _importTotal = files.length;
      _importDone = 0;
    });

    int failed = 0;
    for (final file in files) {
      try {
        final meta = await VaultService.importFile(file);
        await LocalDb.insertVaultItem(meta);
      } catch (_) {
        failed++;
      }
      if (mounted) setState(() => _importDone++);
    }

    if (mounted) setState(() => _importing = false);
    await _loadItems();

    if (mounted) {
      final imported = files.length - failed;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                failed == 0 ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  failed == 0
                      ? '$imported file${imported == 1 ? '' : 's'} added to vault — hidden from gallery'
                      : '$imported added, $failed failed',
                ),
              ),
            ],
          ),
          backgroundColor:
              failed == 0 ? AppColors.success : AppColors.warning,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _deleteItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete from Vault',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Permanently delete "${item['orig_name']}"?\n\nThis cannot be undone.',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await VaultService.deleteVaultFile(
      item['id'] as String,
      item['vault_path'] as String,
    );
    await _loadItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File removed from vault'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _lockVault() {
    ref.read(vaultProvider.notifier).lock();
    Navigator.of(context).pushReplacementNamed(AppRoutes.vaultLock);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: null,
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text('Vault'),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _gridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppColors.textMuted,
            ),
            tooltip: _gridView ? 'List view' : 'Grid view',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
          IconButton(
            icon: const Icon(Icons.lock_open_rounded, color: AppColors.textMuted),
            tooltip: 'Lock vault',
            onPressed: _lockVault,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                )
              : _items.isEmpty
                  ? _buildEmpty()
                  : _gridView
                      ? _buildGrid()
                      : _buildList(),
          if (_importing) _buildImportOverlay(),
        ],
      ),
      floatingActionButton: _importing
          ? null
          : FloatingActionButton(
              onPressed: _pickAndImport,
              backgroundColor: AppColors.primary,
              tooltip: 'Add files to vault',
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded,
                  color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 24),
            const Text(
              'Vault is empty',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tap + to add photos, videos, documents & more.\nFiles are hidden from gallery and file manager.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _items.length,
      itemBuilder: (_, i) => _VaultItemCard(
        item: _items[i],
        onDelete: () => _deleteItem(_items[i]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      separatorBuilder: (_, __) =>
          const Divider(color: AppColors.divider, height: 1),
      itemCount: _items.length,
      itemBuilder: (_, i) => _VaultItemTile(
        item: _items[i],
        onDelete: () => _deleteItem(_items[i]),
      ),
    );
  }

  Widget _buildImportOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.72),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 48),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  value: _importTotal > 0 ? _importDone / _importTotal : null,
                  strokeWidth: 4,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  backgroundColor: AppColors.surfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Adding to vault...',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_importDone / $_importTotal',
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 4),
              const Text(
                'Files are being moved to vault',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Grid Card ─────────────────────────────────────────────────────────────────

class _VaultItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  const _VaultItemCard({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = item['file_type'] as String? ?? 'other';
    final name = item['orig_name'] as String? ?? 'Unknown';
    final size = item['file_size'] as int? ?? 0;
    final vaultPath = item['vault_path'] as String? ?? '';

    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12)),
                child: _FilePreview(type: type, path: vaultPath),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(_typeIcon(type),
                          color: AppColors.textMuted, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        _formatSize(size),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 10),
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

  static IconData _typeIcon(String type) {
    switch (type) {
      case 'image': return Icons.image_rounded;
      case 'video': return Icons.videocam_rounded;
      case 'audio': return Icons.headphones_rounded;
      case 'document': return Icons.description_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

// ── List Tile ─────────────────────────────────────────────────────────────────

class _VaultItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDelete;
  const _VaultItemTile({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type = item['file_type'] as String? ?? 'other';
    final name = item['orig_name'] as String? ?? 'Unknown';
    final size = item['file_size'] as int? ?? 0;
    final vaultPath = item['vault_path'] as String? ?? '';

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: SizedBox(
        width: 52,
        height: 52,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _FilePreview(type: type, path: vaultPath, compact: true),
        ),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        _formatSize(size),
        style:
            const TextStyle(color: AppColors.textMuted, fontSize: 11),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error, size: 22),
        onPressed: onDelete,
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }
}

// ── File preview widget ───────────────────────────────────────────────────────

class _FilePreview extends StatelessWidget {
  final String type;
  final String path;
  final bool compact;
  const _FilePreview(
      {required this.type, required this.path, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (type == 'image' && path.isNotEmpty) {
      final file = File(path);
      try {
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _iconBox(),
          );
        }
      } catch (_) {}
    }
    return _iconBox();
  }

  Widget _iconBox() {
    return Container(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Icon(
          _icon,
          color: AppColors.primary.withOpacity(0.7),
          size: compact ? 24 : 40,
        ),
      ),
    );
  }

  IconData get _icon {
    switch (type) {
      case 'image': return Icons.image_rounded;
      case 'video': return Icons.videocam_rounded;
      case 'audio': return Icons.headphones_rounded;
      case 'document': return Icons.description_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }
}
