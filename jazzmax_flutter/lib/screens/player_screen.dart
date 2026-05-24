import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../core/constants.dart';
import '../core/security/keystore.dart';
import '../core/db/local_db.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String title;
  final String? localPath;
  // For series playback — list of all episodes + current index
  final List<Map<String, dynamic>>? episodes;
  final int episodeIndex;

  const PlayerScreen({
    super.key,
    required this.fileId,
    required this.title,
    this.localPath,
    this.episodes,
    this.episodeIndex = 0,
  });

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoCtrl;

  // Controls
  bool _showControls  = true;
  Timer? _hideTimer;
  bool _locked        = false;

  // Seek flash
  bool _showSeekLeft  = false;
  bool _showSeekRight = false;
  String _seekLabel   = '';

  // Speed
  double _speed = 1.0;
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // Gesture drag
  bool _draggingBrightness = false;
  bool _draggingVolume     = false;
  bool _draggingSeek       = false;
  double? _dragSeekOffset;
  double _brightness = 0.5;
  double _volume     = 0.7;

  // Long press 2x
  bool _longPressFast = false;

  // Panels
  bool _showSpeedPicker   = false;
  bool _showSubtitleMenu  = false;
  bool _showAudioMenu     = false;

  // Skip intro
  bool _skipIntroVisible  = false;
  Timer? _skipIntroTimer;

  // Next Episode
  bool _showNextEpisode   = false;
  int _nextCountdown      = 7;
  Timer? _nextEpTimer;
  late int _currentEpIdx;
  bool get _hasNextEp => widget.episodes != null && _currentEpIdx < widget.episodes!.length - 1;

  // Aspect ratio
  final _ratios = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
  int _ratioIdx = 0;

  // Playback state
  Duration _position  = Duration.zero;
  Duration _duration  = Duration.zero;
  bool _buffering     = true;
  bool _playing       = false;
  bool _ended         = false;

  @override
  void initState() {
    super.initState();
    _currentEpIdx = widget.episodeIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    WakelockPlus.enable();
    _initPlayer();
    _scheduleHide();
    _initBrightnessVolume();
  }

  Future<void> _initBrightnessVolume() async {
    try {
      _brightness = await ScreenBrightness().current;
      _volume     = await VolumeController().getVolume();
    } catch (_) {}
  }

  Future<void> _initPlayer() async {
    _player    = Player();
    _videoCtrl = VideoController(_player);
    await _openMedia(widget.fileId, localPath: widget.localPath);

    _player.stream.position.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      // Save position every 10 seconds
      if (p.inSeconds % 10 == 0 && _duration.inMilliseconds > 0) {
        LocalDb.saveWatchPosition(
            fileId: widget.fileId,
            positionMs: p.inMilliseconds,
            durationMs: _duration.inMilliseconds);
      }
    });
    _player.stream.duration.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _player.stream.buffering.listen((b) {
      if (!mounted) return;
      setState(() => _buffering = b);
    });
    _player.stream.playing.listen((p) {
      if (!mounted) return;
      setState(() => _playing = p);
    });
    _player.stream.completed.listen((done) {
      if (!mounted || !done) return;
      setState(() => _ended = true);
      _onPlaybackEnded();
    });

    // Skip intro hint
    _skipIntroTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _duration.inSeconds > 85) {
        setState(() => _skipIntroVisible = true);
        Timer(const Duration(seconds: 7), () {
          if (mounted) setState(() => _skipIntroVisible = false);
        });
      }
    });
  }

  Future<void> _openMedia(String fileId, {String? localPath}) async {
    final token = await Keystore.getAccessToken();
    final url = localPath != null && localPath.isNotEmpty
        ? localPath
        : '${AppConstants.apiBaseUrl}${ApiPaths.playUrl(fileId)}?token=${token ?? ''}';
    await _player.open(Media(url));
    setState(() { _ended = false; _position = Duration.zero; });
  }

  void _onPlaybackEnded() {
    if (_hasNextEp) {
      _startNextEpCountdown();
    } else {
      // Show controls so user can do something
      setState(() => _showControls = true);
    }
  }

  void _startNextEpCountdown() {
    setState(() { _showNextEpisode = true; _nextCountdown = 7; _showControls = false; });
    _nextEpTimer?.cancel();
    _nextEpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _nextCountdown--);
      if (_nextCountdown <= 0) {
        t.cancel();
        _playNextEpisode();
      }
    });
  }

  void _playNextEpisode() {
    if (!_hasNextEp) return;
    _nextEpTimer?.cancel();
    final next = widget.episodes![_currentEpIdx + 1];
    final nextFileId = next['file_id']?.toString() ?? '';
    final nextLabel  = next['label'] as String? ?? 'Episode ${_currentEpIdx + 2}';
    setState(() {
      _currentEpIdx++;
      _showNextEpisode = false;
      _ended = false;
      _position = Duration.zero;
      _skipIntroVisible = false;
    });
    _openMedia(nextFileId);
    _skipIntroTimer?.cancel();
    _skipIntroTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _duration.inSeconds > 85) {
        setState(() => _skipIntroVisible = true);
        Timer(const Duration(seconds: 7), () {
          if (mounted) setState(() => _skipIntroVisible = false);
        });
      }
    });
  }

  String get _currentTitle {
    if (widget.episodes != null && widget.episodes!.isNotEmpty) {
      final ep = widget.episodes![_currentEpIdx];
      return ep['label'] as String? ?? widget.title;
    }
    return widget.title;
  }

  String get _nextEpLabel {
    if (!_hasNextEp) return '';
    final ep = widget.episodes![_currentEpIdx + 1];
    return ep['label'] as String? ?? 'Episode ${_currentEpIdx + 2}';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _skipIntroTimer?.cancel();
    _nextEpTimer?.cancel();
    // Final position save
    if (_position.inMilliseconds > 0 && _duration.inMilliseconds > 0) {
      LocalDb.saveWatchPosition(
          fileId: widget.fileId,
          positionMs: _position.inMilliseconds,
          durationMs: _duration.inMilliseconds);
    }
    _player.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_showSpeedPicker && !_showSubtitleMenu && !_showAudioMenu) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    if (_showNextEpisode) return;
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    _player.seek(target.clamp(Duration.zero, _duration));
    final label = seconds > 0 ? '+${seconds}s' : '${seconds}s';
    setState(() {
      if (seconds > 0) { _showSeekRight = true; _seekLabel = label; }
      else             { _showSeekLeft  = true; _seekLabel = label; }
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() { _showSeekLeft = false; _showSeekRight = false; });
    });
  }

  void _cycleFit() => setState(() => _ratioIdx = (_ratioIdx + 1) % _ratios.length);

  String get _fitLabel {
    switch (_ratios[_ratioIdx]) {
      case BoxFit.contain: return 'Fit';
      case BoxFit.cover:   return 'Zoom';
      default:             return 'Fill';
    }
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  double get _progressFraction => _duration.inMilliseconds > 0
      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          _seekRelative(d.localPosition.dx < w / 2 ? -10 : 10);
        },
        onLongPressStart: (_) { setState(() => _longPressFast = true); _player.setRate(2.0); },
        onLongPressEnd:   (_) { setState(() => _longPressFast = false); _player.setRate(_speed); },
        onVerticalDragStart:  _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd:    (_) => setState(() { _draggingBrightness = false; _draggingVolume = false; }),
        onHorizontalDragStart:  _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd:    _onHorizontalDragEnd,
        child: Stack(children: [
          // VIDEO
          Positioned.fill(child: Video(
              controller: _videoCtrl, fit: _ratios[_ratioIdx],
              filterQuality: FilterQuality.medium)),

          // Seek flashes
          if (_showSeekLeft)  _SeekFlash(isRight: false, label: _seekLabel),
          if (_showSeekRight) _SeekFlash(isRight: true,  label: _seekLabel),

          // Buffering
          if (_buffering && !_ended)
            const Center(child: SizedBox(width: 40, height: 40,
              child: CircularProgressIndicator(strokeWidth: 2, strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)))),

          // Drag indicators
          if (_draggingBrightness || _draggingVolume)
            _DragIndicator(
              icon: _draggingBrightness ? Icons.brightness_medium_rounded : Icons.volume_up_rounded,
              value: _draggingBrightness ? _brightness : _volume),

          // Long press 2x banner
          if (_longPressFast)
            Positioned(top: 16, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.fast_forward_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('2× Speed', style: TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600)),
                ]))).animate().fadeIn(duration: 200.ms)),

          // Skip intro
          if (_skipIntroVisible && !_locked && !_showNextEpisode)
            Positioned(bottom: 90, right: 20,
              child: GestureDetector(
                onTap: () { _player.seek(const Duration(seconds: 85)); setState(() => _skipIntroVisible = false); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black70,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: Colors.white38)),
                  child: const Text('Skip Intro →', style: TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                )).animate().fadeIn(duration: 300.ms)
                    .slideY(begin: 0.3, end: 0, duration: 300.ms, curve: AppCurves.standard)),

          // ── NEXT EPISODE OVERLAY ──────────────────────────────────────────
          if (_showNextEpisode)
            _NextEpisodeOverlay(
              currentTitle: _currentTitle,
              nextTitle: _nextEpLabel,
              countdown: _nextCountdown,
              onPlay: _playNextEpisode,
              onCancel: () {
                _nextEpTimer?.cancel();
                setState(() => _showNextEpisode = false);
                Navigator.of(context).pop();
              },
              onSkipCountdown: _playNextEpisode,
            ),

          // CONTROLS
          if (_showControls && !_longPressFast && !_showNextEpisode)
            _ControlsOverlay(
              title: _currentTitle,
              playing: _playing,
              buffering: _buffering,
              locked: _locked,
              position: _position,
              duration: _duration,
              progress: _progressFraction,
              speed: _speed,
              fitLabel: _fitLabel,
              hasNext: _hasNextEp,
              currentEp: widget.episodes != null ? _currentEpIdx : null,
              totalEps: widget.episodes?.length,
              onBack:   () => Navigator.of(context).pop(),
              onPlayPause: () => _player.playOrPause(),
              onSeekTo: (frac) {
                final ms = (frac * _duration.inMilliseconds).toInt();
                _player.seek(Duration(milliseconds: ms));
              },
              onSeekBack:    () => _seekRelative(-10),
              onSeekForward: () => _seekRelative(10),
              onLock: () => setState(() { _locked = !_locked; _showControls = false; }),
              onCycleFit: _cycleFit,
              onSpeed: () => setState(() { _showSpeedPicker = !_showSpeedPicker; _scheduleHide(); }),
              onSubtitleFile: _pickSubtitle,
              onSubtitleTracks: () => setState(() { _showSubtitleMenu = !_showSubtitleMenu; }),
              onAudioTracks: () => setState(() { _showAudioMenu = !_showAudioMenu; }),
              onNextEpisode: _hasNextEp ? _playNextEpisode : null,
              fmtDur: _fmtDur,
            ),

          // Lock button when locked
          if (_locked && _showControls)
            Positioned(right: 20, top: 0, bottom: 0,
              child: Center(child: GestureDetector(
                onTap: () => setState(() { _locked = false; _showControls = true; _scheduleHide(); }),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54,
                      border: Border.all(color: Colors.white30)),
                  child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 22))),
              ).animate().fadeIn(duration: 200.ms)),

          // Speed picker panel
          if (_showSpeedPicker && !_locked)
            Positioned(right: 0, top: 0, bottom: 0,
              child: _SpeedPanel(
                currentSpeed: _speed, speeds: _speeds,
                onSelect: (s) { setState(() { _speed = s; _showSpeedPicker = false; }); _player.setRate(s); _scheduleHide(); })),

          // Subtitle tracks
          if (_showSubtitleMenu && !_locked)
            Positioned(right: 0, top: 0, bottom: 0,
              child: _TracksPanel(
                title: 'Subtitles',
                tracks: _player.state.tracks.subtitle.map((t) => t.language ?? t.id ?? 'Track').toList(),
                onSelect: (i) { _player.setSubtitleTrack(_player.state.tracks.subtitle[i]); setState(() => _showSubtitleMenu = false); })),

          // Audio tracks
          if (_showAudioMenu && !_locked)
            Positioned(right: 0, top: 0, bottom: 0,
              child: _TracksPanel(
                title: 'Audio',
                tracks: _player.state.tracks.audio.map((t) => t.language ?? t.id ?? 'Track').toList(),
                onSelect: (i) { _player.setAudioTrack(_player.state.tracks.audio[i]); setState(() => _showAudioMenu = false); })),
        ]),
      ),
    );
  }

  Future<void> _pickSubtitle() async {
    final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['srt', 'ass', 'vtt']);
    if (result?.files.single.path != null) {
      _player.setSubtitleTrack(SubtitleTrack.uri('file://${result!.files.single.path!}'));
    }
  }

  void _onVerticalDragStart(DragStartDetails d) {
    final w = MediaQuery.of(context).size.width;
    if (d.localPosition.dx < w / 2) { _draggingBrightness = true; }
    else { _draggingVolume = true; }
    setState(() {});
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    final h = MediaQuery.of(context).size.height;
    final delta = -d.delta.dy / h;
    if (_draggingBrightness) {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      ScreenBrightness().setScreenBrightness(_brightness);
      setState(() {});
    } else if (_draggingVolume) {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      VolumeController().setVolume(_volume);
      setState(() {});
    }
  }

  void _onHorizontalDragStart(DragStartDetails d) {
    _draggingSeek = true; _dragSeekOffset = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!_draggingSeek) return;
    final w = MediaQuery.of(context).size.width;
    _dragSeekOffset = (_dragSeekOffset ?? 0) + d.delta.dx / w * 120;
    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails _) {
    if (_draggingSeek && _dragSeekOffset != null) {
      final target = _position + Duration(seconds: _dragSeekOffset!.round());
      _player.seek(target.clamp(Duration.zero, _duration));
    }
    setState(() { _draggingSeek = false; _dragSeekOffset = null; });
  }
}

// ── Next Episode Overlay ──────────────────────────────────────────────────────
class _NextEpisodeOverlay extends StatelessWidget {
  final String currentTitle, nextTitle;
  final int countdown;
  final VoidCallback onPlay, onCancel, onSkipCountdown;
  const _NextEpisodeOverlay({required this.currentTitle, required this.nextTitle,
      required this.countdown, required this.onPlay, required this.onCancel,
      required this.onSkipCountdown});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Episode ended label
              const Text('Episode Ended', style: TextStyle(
                  color: Colors.white60, fontSize: 14, letterSpacing: 0.5))
                  .animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 12),
              Text(currentTitle, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 15))
                  .animate(delay: 80.ms).fadeIn(duration: 300.ms),

              const SizedBox(height: 40),

              // Up next banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('UP NEXT', style: TextStyle(
                      color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text(nextTitle, style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700,
                      letterSpacing: -0.3)),
                  const SizedBox(height: 20),
                  // Countdown progress bar
                  Stack(children: [
                    Container(height: 4, decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(2))),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 900),
                      height: 4,
                      width: (MediaQuery.of(context).size.width - 120) * (1 - countdown / 7),
                      decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    // Play next now
                    Expanded(
                      child: GestureDetector(
                        onTap: onPlay,
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: AppShadows.primary),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                            const SizedBox(width: 6),
                            Text('Play Now ($countdown)',
                                style: const TextStyle(color: Colors.white,
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Cancel
                    GestureDetector(
                      onTap: onCancel,
                      child: Container(
                        height: 46, width: 46,
                        decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 22)),
                    ),
                  ]),
                ]),
              ).animate(delay: 150.ms).fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: AppCurves.enter),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Controls Overlay ──────────────────────────────────────────────────────────
class _ControlsOverlay extends StatelessWidget {
  final String title, fitLabel;
  final bool playing, buffering, locked, hasNext;
  final Duration position, duration;
  final double progress, speed;
  final int? currentEp, totalEps;
  final VoidCallback onBack, onPlayPause, onSeekBack, onSeekForward,
      onLock, onCycleFit, onSpeed, onSubtitleFile, onSubtitleTracks, onAudioTracks;
  final VoidCallback? onNextEpisode;
  final ValueChanged<double> onSeekTo;
  final String Function(Duration) fmtDur;

  const _ControlsOverlay({
    required this.title, required this.fitLabel,
    required this.playing, required this.buffering, required this.locked,
    required this.position, required this.duration, required this.progress,
    required this.speed, required this.hasNext, this.currentEp, this.totalEps,
    required this.onBack, required this.onPlayPause,
    required this.onSeekBack, required this.onSeekForward, required this.onLock,
    required this.onCycleFit, required this.onSpeed, required this.onSubtitleFile,
    required this.onSubtitleTracks, required this.onAudioTracks,
    this.onNextEpisode, required this.onSeekTo, required this.fmtDur,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Top scrim
      const Positioned(top: 0, left: 0, right: 0, child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent])),
          child: SizedBox(height: 100))),
      // Bottom scrim
      const Positioned(bottom: 0, left: 0, right: 0, child: DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Color(0xCC000000), Colors.transparent])),
          child: SizedBox(height: 130))),

      // TOP BAR
      Positioned(top: 0, left: 0, right: 0,
        child: SafeArea(child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 20, color: Colors.white), onPressed: onBack),
            const SizedBox(width: 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              if (currentEp != null && totalEps != null)
                Text('Episode ${currentEp! + 1} of $totalEps',
                    style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
            _TopBtn(label: fitLabel, onTap: onCycleFit),
            _TopBtn(label: speed == 1.0 ? '1×' : '${speed}×', onTap: onSpeed),
            IconButton(icon: const Icon(Icons.subtitles_outlined, color: Colors.white, size: 22),
                tooltip: 'Subtitles', onPressed: onSubtitleTracks),
            IconButton(icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 22),
                tooltip: 'Audio', onPressed: onAudioTracks),
            IconButton(icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 22),
                tooltip: 'Lock', onPressed: onLock),
          ]),
        )).animate().fadeIn(duration: 200.ms)),

      // CENTER CONTROLS
      if (!locked)
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _SeekBtn(icon: Icons.replay_10_rounded, onTap: onSeekBack),
          const SizedBox(width: 24),
          GestureDetector(onTap: onPlayPause,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.9), boxShadow: AppShadows.glow),
              child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 38))),
          const SizedBox(width: 24),
          _SeekBtn(icon: Icons.forward_10_rounded, onTap: onSeekForward),
          if (hasNext) ...[
            const SizedBox(width: 16),
            GestureDetector(
              onTap: onNextEpisode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: Colors.white12,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: Colors.white24)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Next', style: TextStyle(color: Colors.white, fontSize: 12)),
                  SizedBox(width: 4),
                  Icon(Icons.skip_next_rounded, color: Colors.white, size: 18),
                ])),
            ),
          ],
        ]).animate().fadeIn(duration: 200.ms)),

      // BOTTOM BAR
      Positioned(bottom: 0, left: 0, right: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(fmtDur(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(fmtDur(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 4),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primaryGlow,
              ),
              child: Slider(value: progress, onChanged: onSeekTo)),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 13, color: Colors.white54),
                label: const Text('Subtitle File', style: TextStyle(color: Colors.white54, fontSize: 10)),
                onPressed: onSubtitleFile,
                style: TextButton.styleFrom(padding: EdgeInsets.zero,
                    minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ]),
          ]).animate().fadeIn(duration: 200.ms),
        )),
    ]);
  }
}

class _TopBtn extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _TopBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))));
}

class _SeekBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _SeekBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 50, height: 50,
      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
      child: Icon(icon, color: Colors.white, size: 28)));
}

// ── Speed Panel ───────────────────────────────────────────────────────────────
class _SpeedPanel extends StatelessWidget {
  final double currentSpeed; final List<double> speeds; final ValueChanged<double> onSelect;
  const _SpeedPanel({required this.currentSpeed, required this.speeds, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Container(width: 140, color: Colors.black87,
      child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(16,16,16,8),
          child: Text('Speed', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        Expanded(child: ListView(children: speeds.map((s) => ListTile(
          title: Text('${s}×', style: TextStyle(
              color: s == currentSpeed ? AppColors.primary : Colors.white,
              fontWeight: s == currentSpeed ? FontWeight.w700 : FontWeight.normal)),
          leading: s == currentSpeed ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 18) : null,
          onTap: () => onSelect(s), dense: true)).toList())),
      ])).animate().slideX(begin: 1, end: 0, duration: 200.ms, curve: AppCurves.standard);
  }
}

// ── Tracks Panel ──────────────────────────────────────────────────────────────
class _TracksPanel extends StatelessWidget {
  final String title; final List<String> tracks; final ValueChanged<int> onSelect;
  const _TracksPanel({required this.title, required this.tracks, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Container(width: 180, color: Colors.black87,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16,16,16,8),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        Expanded(child: tracks.isEmpty
          ? const Center(child: Text('No tracks', style: TextStyle(color: Colors.white54, fontSize: 13)))
          : ListView.builder(itemCount: tracks.length,
              itemBuilder: (_, i) => ListTile(title: Text(tracks[i],
                  style: const TextStyle(color: Colors.white)), dense: true, onTap: () => onSelect(i)))),
      ])).animate().slideX(begin: 1, end: 0, duration: 200.ms, curve: AppCurves.standard);
  }
}

// ── Seek Flash ────────────────────────────────────────────────────────────────
class _SeekFlash extends StatelessWidget {
  final bool isRight; final String label;
  const _SeekFlash({required this.isRight, required this.label});
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Positioned(
      left: isRight ? w / 2 : 0, right: isRight ? 0 : w / 2, top: 0, bottom: 0,
      child: Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: isRight ? Alignment.centerLeft : Alignment.centerRight,
          end:   isRight ? Alignment.centerRight : Alignment.centerLeft,
          colors: [Colors.white.withOpacity(0.08), Colors.transparent])),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isRight ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
              color: Colors.white, size: 36),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ])),
      ),
    ).animate().fadeIn(duration: 150.ms).then().fadeOut(duration: 400.ms, delay: 250.ms);
  }
}

// ── Drag Indicator ────────────────────────────────────────────────────────────
class _DragIndicator extends StatelessWidget {
  final IconData icon; final double value;
  const _DragIndicator({required this.icon, required this.value});
  @override
  Widget build(BuildContext context) {
    return Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(color: Colors.black70, borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        SizedBox(width: 100, child: LinearProgressIndicator(
            value: value, backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 3, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 6),
        Text('${(value * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    ));
  }
}
