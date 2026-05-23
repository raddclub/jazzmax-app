import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../core/api/catalog_api.dart';
import '../core/constants.dart';
import '../core/db/local_db.dart';

/// Full-screen video player — Phase 4
/// Features: custom gesture controls, double-tap seek, swipe brightness/volume,
/// audio track selector, aspect ratio toggle, screen lock, resume position.
class PlayerScreen extends StatefulWidget {
  final String fileId;
  final String title;
  final String? localPath;

  const PlayerScreen({
    super.key,
    required this.fileId,
    required this.title,
    this.localPath,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;

  // Loading / error
  bool _loading = true;
  String? _error;

  // Controls visibility
  bool _controlsVisible = true;
  bool _locked = false;

  // Aspect ratio
  BoxFit _fit = BoxFit.contain;

  // Brightness and volume
  double _brightness = 0.5;
  double _volume = 0.5;
  bool _showBrightness = false;
  bool _showVolume = false;

  // Seek flash
  bool _showSeekFwd = false;
  bool _showSeekBwd = false;

  // Guest mode
  bool _isGuest = false;
  Timer? _guestLimitTimer;

  // Playback speed
  double _playbackSpeed = 1.0;
  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // Timers
  Timer? _controlsTimer;
  Timer? _positionTimer;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);

    // Go fullscreen landscape
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);

    // Keep screen on during playback
    WakelockPlus.enable();

    _initBrightnessVolume();
    _checkGuestMode();
    _loadAndPlay();
    _resetControlsTimer();

    // Save position every 5 seconds
    _positionTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _savePosition();
    });
  }

  // ── Guest mode limit ──────────────────────────────────────────────────────

  Future<void> _checkGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    _isGuest = prefs.getBool(StorageKeys.isGuest) ?? false;
    if (_isGuest) {
      _guestLimitTimer = Timer(const Duration(minutes: 10), () {
        if (mounted) {
          _player.pause();
          _showSubscribePopup();
        }
      });
    }
  }

  void _showSubscribePopup() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1),
                  children: [
                    TextSpan(text: 'Jazz', style: TextStyle(color: AppColors.textPrimary)),
                    TextSpan(text: 'MAX', style: TextStyle(color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'Free Preview Ended',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const Text(
                'You\'ve watched your 10-minute free preview.\nSubscribe to continue watching — data-free on Jazz SIM.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.6),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.subscription, (r) => r.settings.name == AppRoutes.home);
                },
                child: const Text('Subscribe Now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.register, (r) => false);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.textMuted),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Create Free Account', style: TextStyle(color: AppColors.textMuted)),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (r) => false);
                },
                child: const Text('Back to Home', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> _initBrightnessVolume() async {
    try {
      _brightness = await ScreenBrightness().current;
    } catch (_) {}
    try {
      _volume = await VolumeController().getVolume();
      VolumeController().showSystemUI = false;
    } catch (_) {}
  }

  Future<void> _loadAndPlay() async {
    setState(() { _loading = true; _error = null; });
    try {
      final savedMs = await LocalDb.getSavedPosition(widget.fileId);
      final url = await CatalogApi.getStreamUrl(widget.fileId);
      await _player.open(Media(url));

      // Seek to saved position if more than 5 seconds in
      if (savedMs > 5000) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          await _player.seek(Duration(milliseconds: savedMs));
          _showResumeSnack();
        }
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _showResumeSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Resuming where you left off'),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Position saving ───────────────────────────────────────────────────────

  Future<void> _savePosition() async {
    if (_error != null) return;
    final posMs = _player.state.position.inMilliseconds;
    final durMs = _player.state.duration.inMilliseconds;
    if (posMs > 0) {
      await LocalDb.savePosition(widget.fileId, posMs, durationMs: durMs);
    }
  }

  // ── Controls visibility ───────────────────────────────────────────────────

  void _resetControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_locked) setState(() => _controlsVisible = false);
    });
  }

  void _toggleControls() {
    if (_locked) return;
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) _resetControlsTimer();
  }

  // ── Seeking ───────────────────────────────────────────────────────────────

  void _seekRelative(int seconds) async {
    final pos = _player.state.position;
    final dur = _player.state.duration;
    final raw = pos + Duration(seconds: seconds);
    final newPos = raw < Duration.zero ? Duration.zero : (raw > dur ? dur : raw);
    await _player.seek(newPos);

    setState(() {
      _showSeekFwd = seconds > 0;
      _showSeekBwd = seconds < 0;
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() { _showSeekFwd = false; _showSeekBwd = false; });
    });

    // Keep controls visible while seeking
    _resetControlsTimer();
  }

  // ── Brightness & Volume ───────────────────────────────────────────────────

  void _adjustBrightness(double delta) {
    _brightness = (_brightness + delta).clamp(0.0, 1.0);
    try { ScreenBrightness().setScreenBrightness(_brightness); } catch (_) {}
    _showIndicator(brightness: true);
  }

  void _adjustVolume(double delta) {
    _volume = (_volume + delta).clamp(0.0, 1.0);
    try { VolumeController().setVolume(_volume); } catch (_) {}
    _showIndicator(volume: true);
  }

  void _showIndicator({bool brightness = false, bool volume = false}) {
    setState(() {
      _showBrightness = brightness;
      _showVolume = volume;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() { _showBrightness = false; _showVolume = false; });
    });
  }

  // ── Subtitle tracks ───────────────────────────────────────────────────────

  void _showSubtitleTracks() {
    final tracks = _player.state.tracks.subtitle;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Subtitles',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
          ),
          // Off option
          ListTile(
            title: const Text('Off',
                style: TextStyle(color: AppColors.textPrimary)),
            leading: Icon(
              _player.state.track.subtitle.id == 'no'
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: AppColors.primary,
            ),
            onTap: () {
              _player.setSubtitleTrack(SubtitleTrack.no());
              Navigator.pop(context);
            },
          ),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text('No subtitle tracks in this video',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            )
          else
            ...tracks.map((t) {
              final isCurrent = _player.state.track.subtitle.id == t.id;
              final label = t.title ?? t.language ?? 'Track ${t.id}';
              return ListTile(
                title: Text(label,
                    style: const TextStyle(color: AppColors.textPrimary)),
                leading: Icon(
                  isCurrent
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                onTap: () {
                  _player.setSubtitleTrack(t);
                  Navigator.pop(context);
                },
              );
            }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Playback speed ────────────────────────────────────────────────────────

  void _showSpeedSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Playback Speed',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: _speeds.map((s) {
              final selected = s == _playbackSpeed;
              return GestureDetector(
                onTap: () {
                  _player.setRate(s);
                  setState(() => _playbackSpeed = s);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 75,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    s == 1.0 ? 'Normal' : '${s}x',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Audio tracks ──────────────────────────────────────────────────────────

  void _showAudioTracks() {
    final tracks = _player.state.tracks.audio;
    if (tracks.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Audio Track',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                )),
          ),
          ...tracks.map((t) {
            final isCurrent = _player.state.track.audio.id == t.id;
            final label = t.title ?? t.language ?? 'Track ${t.id}';
            return ListTile(
              title: Text(label,
                  style: const TextStyle(color: AppColors.textPrimary)),
              leading: Icon(
                isCurrent
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: AppColors.primary,
              ),
              onTap: () {
                _player.setAudioTrack(t);
                Navigator.pop(context);
              },
            );
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Aspect ratio ──────────────────────────────────────────────────────────

  void _cycleAspectRatio() {
    setState(() {
      if (_fit == BoxFit.contain) {
        _fit = BoxFit.cover;
      } else if (_fit == BoxFit.cover) {
        _fit = BoxFit.fill;
      } else {
        _fit = BoxFit.contain;
      }
    });
  }

  String get _fitLabel {
    if (_fit == BoxFit.contain) return 'Fit';
    if (_fit == BoxFit.cover) return 'Crop';
    return 'Fill';
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _controlsTimer?.cancel();
    _positionTimer?.cancel();
    _indicatorTimer?.cancel();
    _guestLimitTimer?.cancel();
    _savePosition();
    _player.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    try { ScreenBrightness().resetScreenBrightness(); } catch (_) {}
    try { VolumeController().showSystemUI = true; } catch (_) {}
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Video rendering
          Positioned.fill(
            child: Video(
              controller: _controller,
              fit: _fit,
              controls: (state) => const SizedBox.shrink(),
            ),
          ),

          // 2. Loading
          if (_loading)
            const Center(
              child: CircularProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),

          // 3. Error
          if (_error != null)
            Center(child: _buildError()),

          // 4. Gesture layer — left half & right half side by side
          if (!_loading && _error == null)
            Positioned.fill(child: _buildGestureLayer()),

          // 5. Controls overlay (hidden when _locked or invisible)
          IgnorePointer(
            ignoring: !_controlsVisible || _locked,
            child: AnimatedOpacity(
              opacity: (_controlsVisible && !_locked) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _buildControlsOverlay(),
            ),
          ),

          // 6. Lock indicator (tap to unlock)
          if (_locked)
            Positioned(
              top: 20,
              right: 20,
              child: SafeArea(
                child: GestureDetector(
                  onTap: () => setState(() => _locked = false),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded,
                            color: AppColors.primary, size: 18),
                        SizedBox(width: 4),
                        Text('Tap to unlock',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 7. Seek flash indicators
          if (_showSeekBwd)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.5,
              child: const Center(child: _SeekFlash(forward: false)),
            ),
          if (_showSeekFwd)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.5,
              child: const Center(child: _SeekFlash(forward: true)),
            ),

          // 8. Brightness bar (left edge)
          if (_showBrightness)
            Positioned(
              left: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: _VerticalBar(
                  value: _brightness,
                  icon: Icons.brightness_6_rounded,
                  label: '${(_brightness * 100).round()}%',
                ),
              ),
            ),

          // 9. Volume bar (right edge)
          if (_showVolume)
            Positioned(
              right: 20,
              top: 0,
              bottom: 0,
              child: Center(
                child: _VerticalBar(
                  value: _volume,
                  icon: Icons.volume_up_rounded,
                  label: '${(_volume * 100).round()}%',
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Gesture layer ─────────────────────────────────────────────────────────

  Widget _buildGestureLayer() {
    return Row(
      children: [
        // Left half: double-tap → -10s, drag → brightness
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: () => _seekRelative(-10),
            onVerticalDragUpdate: (d) =>
                _adjustBrightness(-d.delta.dy / 160),
            child: const SizedBox.expand(),
          ),
        ),
        // Right half: double-tap → +10s, drag → volume
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTap: () => _seekRelative(10),
            onVerticalDragUpdate: (d) =>
                _adjustVolume(-d.delta.dy / 160),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }

  // ── Controls overlay ──────────────────────────────────────────────────────

  Widget _buildControlsOverlay() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black54,
            Colors.transparent,
            Colors.transparent,
            Colors.black54,
          ],
          stops: [0.0, 0.25, 0.75, 1.0],
        ),
      ),
      child: Column(
        children: [
          // Top bar
          _buildTopBar(),
          // Center play/pause
          Expanded(child: _buildCenterControls()),
          // Bottom bar
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Subtitles
            IconButton(
              icon: const Icon(Icons.subtitles_outlined,
                  color: Colors.white, size: 20),
              tooltip: 'Subtitles',
              onPressed: _showSubtitleTracks,
            ),
            // Audio track picker
            IconButton(
              icon: const Icon(Icons.audiotrack_rounded,
                  color: Colors.white, size: 20),
              tooltip: 'Audio Track',
              onPressed: _showAudioTracks,
            ),
            // Playback speed
            GestureDetector(
              onTap: _showSpeedSelector,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  _playbackSpeed == 1.0 ? '1x' : '${_playbackSpeed}x',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            // Aspect ratio
            TextButton(
              onPressed: _cycleAspectRatio,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                minimumSize: Size.zero,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(_fitLabel,
                  style: const TextStyle(fontSize: 12)),
            ),
            // Screen lock
            IconButton(
              icon: const Icon(Icons.lock_open_rounded,
                  color: Colors.white, size: 20),
              tooltip: 'Lock screen',
              onPressed: () => setState(() => _locked = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterControls() {
    return StreamBuilder<bool>(
      stream: _player.stream.playing,
      builder: (_, snap) {
        final playing = snap.data ?? false;
        return Center(
          child: GestureDetector(
            onTap: () {
              _player.playOrPause();
              _resetControlsTimer();
            },
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: Icon(
                playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress slider
            StreamBuilder<Duration>(
              stream: _player.stream.position,
              builder: (_, posSnap) {
                return StreamBuilder<Duration>(
                  stream: _player.stream.duration,
                  builder: (_, durSnap) {
                    final pos =
                        posSnap.data ?? Duration.zero;
                    final dur =
                        durSnap.data ?? Duration.zero;
                    final progress = dur.inMilliseconds > 0
                        ? (pos.inMilliseconds /
                                dur.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            activeTrackColor:
                                AppColors.primary,
                            inactiveTrackColor:
                                Colors.white30,
                            thumbColor: Colors.white,
                            overlayShape:
                                SliderComponentShape.noOverlay,
                          ),
                          child: Slider(
                            value: progress,
                            onChanged: (v) {
                              final newPos = Duration(
                                  milliseconds:
                                      (v * dur.inMilliseconds)
                                          .round());
                              _player.seek(newPos);
                              _resetControlsTimer();
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(pos),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12),
                              ),
                              Text(
                                _formatDuration(dur),
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              color: AppColors.error, size: 48),
          const SizedBox(height: 16),
          Text(
            'Could not load stream.\n${_error!}',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadAndPlay,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back',
                style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SeekFlash extends StatelessWidget {
  final bool forward;
  const _SeekFlash({required this.forward});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward
                ? Icons.fast_forward_rounded
                : Icons.fast_rewind_rounded,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            forward ? '+10s' : '-10s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalBar extends StatelessWidget {
  final double value;
  final IconData icon;
  final String label;
  const _VerticalBar(
      {required this.value, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: RotatedBox(
              quarterTurns: -1,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary),
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}
