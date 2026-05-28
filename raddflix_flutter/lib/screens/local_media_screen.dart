import 'dart:typed_data';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:flutter_animate/flutter_animate.dart';
  import 'package:shimmer/shimmer.dart';
  import '../core/constants.dart';
  import '../models/local_video.dart';
  import '../services/local_media_service.dart';
  import 'local_folder_screen.dart';
  import '../widgets/bottom_nav.dart';

  class LocalMediaScreen extends StatefulWidget {
    const LocalMediaScreen({super.key});
    @override
    State<LocalMediaScreen> createState() => _LocalMediaScreenState();
  }

  enum _LocalSortMode { name, size, date, count }
  enum _LocalViewMode { list, grid }

  class _LocalMediaScreenState extends State<LocalMediaScreen>
      with AutomaticKeepAliveClientMixin {
    @override
    bool get wantKeepAlive => true;

    List<LocalFolder> _folders = [];
    bool _loading = true;
    bool _permissionDenied = false;
    _LocalSortMode _sort = _LocalSortMode.date;
    _LocalViewMode _view = _LocalViewMode.list;
    String _searchQuery = '';
    bool _searching = false;
    final TextEditingController _searchCtrl = TextEditingController();
    final FocusNode _searchFocus = FocusNode();

    // Thumbnails cache: folderPath → Uint8List
    final Map<String, Uint8List?> _thumbCache = {};

    @override
    void initState() {
      super.initState();
      _load();
    }

    @override
    void dispose() {
      _searchCtrl.dispose();
      _searchFocus.dispose();
      super.dispose();
    }

    Future<void> _load({bool refresh = false}) async {
      setState(() => _loading = true);

      final hasPermission = await LocalMediaService.checkPermission();
      if (!hasPermission) {
        final granted = await LocalMediaService.requestPermission();
        if (!granted) {
          setState(() { _loading = false; _permissionDenied = true; });
          return;
        }
      }

      final videos = await LocalMediaService.queryAllVideos();
      final folders = LocalMediaService.groupByFolder(videos);
      final seen = await LocalMediaService.getSeenPaths();

      // Count new files per folder
      for (final folder in folders) {
        folder.newCount = folder.videos.where((v) => !seen.contains(v.filePath)).length;
      }

      setState(() {
        _folders = folders;
        _loading = false;
        _permissionDenied = false;
      });

      // Load thumbnails lazily in background
      _loadThumbnails(folders);
    }

    Future<void> _loadThumbnails(List<LocalFolder> folders) async {
      for (final folder in folders) {
        if (!mounted) return;
        final first = folder.firstVideo;
        if (first == null) continue;
        if (_thumbCache.containsKey(folder.path)) continue;
        final thumb = await LocalMediaService.getThumbnail(first.filePath, quality: 40, maxDimension: 160);
        if (mounted) setState(() => _thumbCache[folder.path] = thumb);
      }
    }

    List<LocalFolder> get _sorted {
      final list = _searchQuery.isEmpty
          ? List<LocalFolder>.from(_folders)
          : _folders.where((f) =>
              f.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
      switch (_sort) {
        case _LocalSortMode.name:  list.sort((a, b) => a.name.compareTo(b.name));
        case _LocalSortMode.size:  list.sort((a, b) => b.totalSizeBytes.compareTo(a.totalSizeBytes));
        case _LocalSortMode.count: list.sort((a, b) => b.videos.length.compareTo(a.videos.length));
        case _LocalSortMode.date:  break; // already sorted by date
      }
      return list;
    }

    int get _totalVideos => _folders.fold(0, (s, f) => s + f.videos.length);

    @override
    Widget build(BuildContext context) {
      super.build(context);
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(children: [
            _buildTopBar(),
            if (_searching) _buildSearchBar(),
            Expanded(child: _buildBody()),
          ]),
        ),
      );
    }

    Widget _buildTopBar() {
      return Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          const Text('Folders',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          // Total count badge
          if (!_loading && _folders.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.round),
              ),
              child: Text('$_totalVideos videos',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            ),
          const SizedBox(width: 8),
          // Search
          IconButton(
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) { _searchQuery = ''; _searchCtrl.clear(); }
                else _searchFocus.requestFocus();
              });
            },
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          // View toggle
          IconButton(
            icon: Icon(
              _view == _LocalViewMode.list
                  ? Icons.grid_view_rounded
                  : Icons.view_list_rounded,
              color: AppColors.textSecondary, size: 22),
            onPressed: () => setState(() =>
                _view = _view == _LocalViewMode.list
                    ? _LocalViewMode.grid
                    : _LocalViewMode.list),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
          // Sort
          PopupMenuButton<_LocalSortMode>(
            icon: const Icon(Icons.sort_rounded, color: AppColors.textSecondary, size: 22),
            color: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            onSelected: (m) => setState(() => _sort = m),
            itemBuilder: (_) => [
              _sortItem(_LocalSortMode.date,  Icons.access_time_rounded,   'Most Recent',   _sort),
              _sortItem(_LocalSortMode.name,  Icons.sort_by_alpha_rounded, 'Name',          _sort),
              _sortItem(_LocalSortMode.size,  Icons.storage_rounded,       'Size',          _sort),
              _sortItem(_LocalSortMode.count, Icons.video_library_rounded, 'Video Count',   _sort),
            ],
          ),
        ]),
      );
    }

    PopupMenuItem<_LocalSortMode> _sortItem(
        _LocalSortMode mode, IconData icon, String label, _LocalSortMode current) {
      final active = current == mode;
      return PopupMenuItem(
        value: mode,
        child: Row(children: [
          Icon(icon, color: active ? AppColors.primary : AppColors.textMuted, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(
              color: active ? AppColors.primary : AppColors.textPrimary, fontSize: 14,
              fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
          if (active) ...[const Spacer(),
            const Icon(Icons.check_rounded, color: AppColors.primary, size: 16)],
        ]),
      );
    }

    Widget _buildSearchBar() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          controller: _searchCtrl,
          focusNode: _searchFocus,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Search folders…',
            hintStyle: const TextStyle(color: AppColors.textMuted),
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      );
    }

    Widget _buildBody() {
      if (_loading) return _buildShimmer();
      if (_permissionDenied) return _buildPermissionError();
      final sorted = _sorted;
      if (sorted.isEmpty) return _buildEmpty();

      if (_view == _LocalViewMode.grid) {
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 1.4,
              crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: sorted.length,
          itemBuilder: (_, i) => _FolderGridCard(
            folder: sorted[i],
            thumb: _thumbCache[sorted[i].path],
            onTap: () => _openFolder(sorted[i]),
          ).animate(delay: (i * 25).ms).fadeIn(duration: 200.ms),
        );
      }

      return RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () => _load(refresh: true),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
          itemCount: sorted.length,
          itemBuilder: (_, i) => _FolderListTile(
            folder: sorted[i],
            thumb: _thumbCache[sorted[i].path],
            onTap: () => _openFolder(sorted[i]),
          ).animate(delay: (i * 20).ms).fadeIn(duration: 200.ms),
        ),
      );
    }

    void _openFolder(LocalFolder folder) async {
      // Mark all files in this folder as seen
      await LocalMediaService.markSeen(folder.videos.map((v) => v.filePath).toList());
      if (!mounted) return;
      setState(() => folder.newCount = 0);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => LocalFolderScreen(folder: folder),
      ));
    }

    Widget _buildPermissionError() {
      return Center(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: AppColors.error.withOpacity(0.1)),
            child: const Icon(Icons.folder_off_rounded, color: AppColors.error, size: 40)),
          const SizedBox(height: 24),
          const Text('Storage Permission Required',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18,
                  fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          const Text('RaddFlix needs permission to browse your videos',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings_rounded, size: 18),
            label: const Text('Open Settings'),
            onPressed: () {
              const MethodChannel('com.raddflix.app/media_store')
                  .invokeMethod('openAppSettings');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _load,
            child: const Text('Try Again', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ]),
      ));
    }

    Widget _buildEmpty() {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.video_library_outlined, color: AppColors.textMuted, size: 56),
        const SizedBox(height: 16),
        Text(_searchQuery.isNotEmpty ? 'No folders match "$_searchQuery"' : 'No videos found',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 15)),
      ]));
    }

    Widget _buildShimmer() {
      return ListView.builder(
        itemCount: 7,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor: AppColors.surface,
          highlightColor: AppColors.surfaceHigh,
          child: Container(
            height: 72, margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            decoration: BoxDecoration(color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md))),
        ),
      );
    }
  }

  // ── Folder list tile (MX Player style) ────────────────────────────────────────
  class _FolderListTile extends StatelessWidget {
    final LocalFolder folder;
    final Uint8List? thumb;
    final VoidCallback onTap;
    const _FolderListTile({required this.folder, required this.thumb, required this.onTap});

    @override
    Widget build(BuildContext context) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: SizedBox(
            height: 72,
            child: Row(children: [
              // Thumbnail / folder icon
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: SizedBox(
                  width: 64, height: 56,
                  child: thumb != null
                      ? Image.memory(thumb!, fit: BoxFit.cover)
                      : Container(color: AppColors.surface,
                          child: const Icon(Icons.folder_rounded,
                              color: AppColors.textMuted, size: 28)),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary,
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('${folder.videos.length} video${folder.videos.length == 1 ? '' : 's'}  •  ${folder.formattedTotalSize}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              )),
              // New badge
              if (folder.newCount > 0)
                Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                  child: Center(child: Text(
                    folder.newCount > 99 ? '99+' : '${folder.newCount}',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                  )),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
            ]),
          ),
        ),
      );
    }
  }

  // ── Folder grid card ──────────────────────────────────────────────────────────
  class _FolderGridCard extends StatelessWidget {
    final LocalFolder folder;
    final Uint8List? thumb;
    final VoidCallback onTap;
    const _FolderGridCard({required this.folder, required this.thumb, required this.onTap});

    @override
    Widget build(BuildContext context) {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Stack(fit: StackFit.expand, children: [
            thumb != null
                ? Image.memory(thumb!, fit: BoxFit.cover)
                : Container(color: AppColors.surface,
                    child: const Icon(Icons.folder_rounded, color: AppColors.textMuted, size: 36)),
            // Gradient scrim
            DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
              ))),
            // Labels
            Positioned(bottom: 8, left: 10, right: 10, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${folder.videos.length} videos  ${folder.formattedTotalSize}',
                    style: const TextStyle(color: Colors.white60, fontSize: 10)),
              ],
            )),
            if (folder.newCount > 0)
              Positioned(top: 6, right: 6,
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                  child: Center(child: Text('${folder.newCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
                )),
          ]),
        ),
      );
    }
  }
  