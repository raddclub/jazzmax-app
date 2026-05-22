import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/api/catalog_api.dart';
import '../core/constants.dart';

class PlayerScreen extends StatefulWidget {
  final String fileId;
  final String title;

  const PlayerScreen({
    super.key,
    required this.fileId,
    required this.title,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    // Go fullscreen landscape for video
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    _loadAndPlay();
  }

  Future<void> _loadAndPlay() async {
    setState(() { _loading = true; _error = null; });
    try {
      final url = await CatalogApi.getStreamUrl(widget.fileId);
      await _player.open(Media(url));
      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load video.\n${e.toString()}';
      });
    }
  }

  @override
  void dispose() {
    _player.dispose();
    // Restore portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Video player ───────────────────────────────────────────────
          Center(
            child: Video(
              controller: _controller,
              controls: MaterialVideoControls,
            ),
          ),

          // ── Loading overlay ────────────────────────────────────────────
          if (_loading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Loading stream...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),

          // ── Error state ────────────────────────────────────────────────
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _loadAndPlay,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),

          // ── Back button ────────────────────────────────────────────────
          if (!_loading && _error == null)
            Positioned(
              top: 16,
              left: 16,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new,
                      color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

          // ── Title bar at top ───────────────────────────────────────────
          if (!_loading && _error == null)
            Positioned(
              top: 16,
              left: 60,
              right: 16,
              child: SafeArea(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
