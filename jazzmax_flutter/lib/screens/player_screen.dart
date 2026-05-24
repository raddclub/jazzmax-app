import 'dart:async';
import 'dart:typed_data';
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
import 'package:video_thumbnail/video_thumbnail.dart';
import '../services/cast_service.dart';
import '../core/constants.dart';
import '../core/security/keystore.dart';
import '../core/db/local_db.dart';

// ── PiP Method Channel ────────────────────────────────────────────────────────
const _pipChannel = MethodChannel('com.jazzmax.app/pip');

class PlayerScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String title;
  final String? localPath;
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final Player _player;
  late final VideoController _videoCtrl;

  // Controls
  bool _showControls = true;
  Timer? _hideTimer;
  bool _locked = false;

  // Seek flash
  bool _showSeekLeft = false;
  bool _showSeekRight = false;
  String _seekLabel = '';

  // Speed
  double _speed = 1.0;
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // Gesture state (unified scale handler)
  String? _dragIntent; // 'brightness' | 'volume' | 'seek' | 'swipe_zoom' | 'pinch'
  Offset _dragStartLocal = Offset.zero;
  double _startScale = 1.0;
  double _startBrightness = 0.5;
  double _startVolume = 0.7;
  Duration _dragStartPosition = Duration.zero;
  bool _draggingBrightness = false;
  bool _draggingVolume = false;
  bool _draggingSeek = false;
  double? _dragSeekDelta; // seconds offset while scrubbing

  // Long press 2×
  bool _longPressFast = false;

  // Panels
  bool _showSpeedPicker = false;
  bool _showSubtitleMenu = false;
  bool _showAudioMenu = false;
  bool _showSleepMenu = false;

  // Zoom & pan
  double _scale = 1.0;
  bool _castConnected = false;

  // Skip intro
  bool _skipIntroVisible = false;
  Timer? _skipIntroTimer;

  // Next Episode
  bool _showNextEpisode = false;
  int _nextCountdown = 7;
  Timer? _nextEpTimer;
  late int _currentEpIdx;
  bool get _hasNextEp =>
      widget.episodes != null && _currentEpIdx < widget.episodes!.length - 1;

  // Aspect ratio
  final _ratios = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
  int _ratioIdx = 0;

  // Playback state
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _buffering = true;
  bool _playing = false;
  bool _ended = false;

  // Sleep timer
  int? _sleepRemainingSeconds;
  Timer? _sleepTimer;

  // PiP
  bool _inPiP = false;

  // Background audio — track if user explicitly paused
  bool _userPaused = false;

  // Seek thumbnail (local/downloaded only)
  Uint8List? _seekThumb;
  Timer? _seekThumbDebounce;
  bool _sliderDragging = false;
  double _sliderDragValue = 0.0;

  bool get _isLocalFile =>
      widget.localPath != null && widget.localPath!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentEpIdx = widget.episodeIndex;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    WakelockPlus.enable();
    _initPlayer();
    _scheduleHide();
    _initBrightnessVolume();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Background audio: don't pause if user didn't pause
      if (!_userPaused) {
        // Keep playing for background audio — just disable wakelock
        WakelockPlus.disable();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (!_userPaused) WakelockPlus.enable();
    }
  }

  Future<void> _initBrightnessVolume() async {
    try {
      _brightness = await ScreenBrightness().current;
      _volume = await VolumeController().getVolume();
    } catch (_) {}
  }
  double _brightness = 0.5;
  double _volume = 0.7;

  Future<void> _initPlayer() async {
    _player = Player();
    _videoCtrl = VideoController(_player);
    await _openMedia(widget.fileId, localPath: widget.localPath);

    _player.stream.position.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
      if (p.inSeconds % 10 == 0 && _duration.inMilliseconds > 0) {
        LocalDb.saveWatchPosition(
            fileId: widget.fileId,
            positionMs: p.inMilliseconds,
            durationMs: _duration.inMilliseconds);
      }
      // Sleep timer
      if (_sleepRemainingSeconds != null && _sleepRemainingSeconds! <= 0) {
        _cancelSleepTimer();
        _player.pause();
        _userPaused = true;
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
    setState(() {
      _ended = false;
      _position = Duration.zero;
    });
  }

  void _onPlaybackEnded() {
    if (_hasNextEp) {
      _startNextEpCountdown();
    } else {
      setState(() => _showControls = true);
    }
  }

  void _startNextEpCountdown() {
    setState(() {
      _showNextEpisode = true;
      _nextCountdown = 7;
      _showControls = false;
    });
    _nextEpTimer?.cancel();
    _nextEpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
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

  // ── Sleep Timer ───────────────────────────────────────────────────────────
  void _setSleepTimer(int minutes) {
    _cancelSleepTimer();
    if (minutes <= 0) return;
    setState(() => _sleepRemainingSeconds = minutes * 60);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _sleepRemainingSeconds = (_sleepRemainingSeconds ?? 0) - 1;
        if (_sleepRemainingSeconds! <= 0) {
          t.cancel();
          _sleepRemainingSeconds = null;
          _player.pause();
          _userPaused = true;
          setState(() => _showControls = true);
        }
      });
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    setState(() => _sleepRemainingSeconds = null);
  }

  // ── PiP ──────────────────────────────────────────────────────────────────
  Future<void> _enterPiP() async {
    try {
      await _pipChannel.invokeMethod('enterPiP');
      setState(() => _inPiP = true);
    } catch (_) {}
  }

  Future<void> _enterCast() async {
    final devices = await CastService.discoverDevices();
    final connected = await CastService.isConnected();
    if (!mounted) return;
    if (connected) {
      // Already casting — show disconnect option
      final stop = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text('Casting Active', style: TextStyle(color: Colors.white)),
          content: const Text('Stop casting to this device?',
              style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep Casting')),
            TextButton(onPressed: () => Navigator.pop(context, true),
                child: const Text('Stop', style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      );
      if (stop == true) {
        await CastService.stop();
        await CastService.disconnect();
        if (mounted) setState(() => _castConnected = false);
      }
      return;
    }
    // No device found via discovery — open system Cast dialog
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final url  = args?['stream_url'] as String? ?? args?['local_path'] as String? ?? '';
    final title = args?['title'] as String? ?? _title;
    final ok = await CastService.castVideo(
      url: url,
      title: title,
      positionMs: _position.inMilliseconds,
    );
    if (mounted) setState(() => _castConnected = ok);
  }

  // ── Seek Thumbnail ────────────────────────────────────────────────────────
  void _updateSeekThumb(double fraction) {
    if (!_isLocalFile) return;
    _seekThumbDebounce?.cancel();
    _seekThumbDebounce = Timer(const Duration(milliseconds: 120), () async {
      final ms = (fraction * _duration.inMilliseconds).toInt();
      try {
        final thumb = await VideoThumbnail.thumbnailData(
          video: widget.localPath!,
          timeMs: ms,
          quality: 60,
          maxWidth: 160,
        );
        if (mounted) setState(() => _seekThumb = thumb);
      } catch (_) {}
    });
  }

  // ── Gesture Handlers (unified onScale) ────────────────────────────────────
  void _onScaleStart(ScaleStartDetails d) {
    _dragStartLocal = d.localFocalPoint;
    _startBrightness = _brightness;
    _startVolume = _volume;
    _dragStartPosition = _position;
    if (d.pointerCount >= 2) {
      _dragIntent = 'pinch';
      _startScale = _scale;
    } else {
      _dragIntent = null;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_locked) return;

    // Pinch-to-zoom
    if (d.pointerCount >= 2 || _dragIntent == 'pinch') {
      _dragIntent = 'pinch';
      setState(() => _scale = (_startScale * d.scale).clamp(1.0, 5.0));
      return;
    }

    final delta = d.localFocalPoint - _dragStartLocal;
    final size = MediaQuery.of(context).size;

    // Determine drag intent once
    if (_dragIntent == null) {
      if (delta.dx.abs() > delta.dy.abs() && delta.dx.abs() > 12) {
        _dragIntent = 'seek';
      } else if (delta.dy.abs() > delta.dx.abs() && delta.dy.abs() > 12) {
        if (delta.dy < 0) {
          _dragIntent = 'swipe_zoom';
        } else {
          _dragIntent =
              d.localFocalPoint.dx < size.width / 2 ? 'brightness' : 'volume';
        }
      }
    }

    switch (_dragIntent) {
      case 'brightness':
        final newB =
            (_startBrightness - delta.dy / size.height * 1.5).clamp(0.0, 1.0);
        ScreenBrightness().setScreenBrightness(newB);
        setState(() {
          _brightness = newB;
          _draggingBrightness = true;
          _draggingVolume = false;
        });
      case 'volume':
        final newV =
            (_startVolume - delta.dy / size.height * 1.5).clamp(0.0, 1.0);
        VolumeController().setVolume(newV);
        setState(() {
          _volume = newV;
          _draggingVolume = true;
          _draggingBrightness = false;
        });
      case 'seek':
        // Max 2 min per full-width swipe
        final seconds =
            (delta.dx / size.width * 120).clamp(-120.0, 120.0);
        setState(() {
          _dragSeekDelta = seconds;
          _draggingSeek = true;
        });
      case 'swipe_zoom':
        // Swipe up to zoom: up = zoom in
        final zoomDelta = (-delta.dy / size.height * 3.0);
        setState(() => _scale = (1.0 + zoomDelta).clamp(1.0, 5.0));
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_dragIntent == 'seek' && _dragSeekDelta != null) {
      final newPos =
          _dragStartPosition + Duration(seconds: _dragSeekDelta!.toInt());
      _player.seek((newPos < Duration.zero ? Duration.zero : newPos > _duration ? _duration : newPos));
    }
    setState(() {
      _draggingBrightness = false;
      _draggingVolume = false;
      _draggingSeek = false;
      _dragSeekDelta = null;
      _dragIntent = null;
    });
  }

  // ── Subtitle File Picker ──────────────────────────────────────────────────
  Future<void> _pickSubtitle() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['srt', 'ass', 'vtt']);
    if (r == null || r.files.single.path == null) return;
    await _player.setSubtitleTrack(SubtitleTrack.uri(r.files.single.path!));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _skipIntroTimer?.cancel();
    _nextEpTimer?.cancel();
    _sleepTimer?.cancel();
    _seekThumbDebounce?.cancel();
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
      if (mounted &&
          !_showSpeedPicker &&
          !_showSubtitleMenu &&
          !_showAudioMenu &&
          !_showSleepMenu) {
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
    _player.seek((target < Duration.zero ? Duration.zero : target > _duration ? _duration : target));
    final label = seconds > 0 ? '+${seconds}s' : '${seconds}s';
    setState(() {
      if (seconds > 0) {
        _showSeekRight = true;
        _seekLabel = label;
      } else {
        _showSeekLeft = true;
        _seekLabel = label;
      }
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() {
        _showSeekLeft = false;
        _showSeekRight = false;
      });
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
    if (h > 0) {
      return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progressFraction => _duration.inMilliseconds > 0
      ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  String get _sleepLabel {
    if (_sleepRemainingSeconds == null) return '';
    final m = _sleepRemainingSeconds! ~/ 60;
    final s = _sleepRemainingSeconds! % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // Seek preview position while scrubbing
  Duration get _previewPosition {
    if (_sliderDragging) {
      return Duration(
          milliseconds: (_sliderDragValue * _duration.inMilliseconds).toInt());
    }
    if (_draggingSeek && _dragSeekDelta != null) {
      final p =
          _dragStartPosition + Duration(seconds: _dragSeekDelta!.toInt());
      return (p < Duration.zero ? Duration.zero : p > _duration ? _duration : p);
    }
    return _position;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        onDoubleTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          if (_scale > 1.01) {
            // Double-tap to reset zoom
            setState(() { _scale = 1.0; });
            return;
          }
          _seekRelative(d.localPosition.dx < w / 2 ? -10 : 10);
        },
        onLongPressStart: (_) {
          setState(() => _longPressFast = true);
          _player.setRate(2.0);
        },
        onLongPressEnd: (_) {
          setState(() => _longPressFast = false);
          _player.setRate(_speed);
        },
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: Stack(children: [
          // ── VIDEO with zoom ──
          Positioned.fill(
            child: Transform.scale(
              scale: _scale,
              child: Video(
                controller: _videoCtrl,
                fit: _ratios[_ratioIdx],
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),

          // ── Seek flash ──
          if (_showSeekLeft) _SeekFlash(isRight: false, label: _seekLabel),
          if (_showSeekRight) _SeekFlash(isRight: true, label: _seekLabel),

          // ── Buffering ──
          if (_buffering && !_ended)
            const Center(
              child: SizedBox(
                width: 40, height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70)),
              ),
            ),

          // ── Drag Indicator (brightness / volume) ──
          if (_draggingBrightness || _draggingVolume)
            _DragIndicator(
              icon: _draggingBrightness
                  ? Icons.brightness_medium_rounded
                  : Icons.volume_up_rounded,
              value: _draggingBrightness ? _brightness : _volume,
            ),

          // ── Seek scrub label ──
          if (_draggingSeek && _dragSeekDelta != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${_fmtDur(_previewPosition)}  (${_dragSeekDelta! >= 0 ? '+' : ''}${_dragSeekDelta!.toInt()}s)',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),

          // ── Zoom indicator ──
          if (_scale > 1.02 && _dragIntent == 'pinch')
            Positioned(
              top: 20, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_scale.toStringAsFixed(1)}×',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),

          // ── Long press 2× ──
          if (_longPressFast)
            Positioned(
              top: 16, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.fast_forward_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('2× Speed',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ).animate().fadeIn(duration: 200.ms),
            ),

          // ── Sleep timer badge ──
          if (_sleepRemainingSeconds != null && !_showControls)
            Positioned(
              top: 16, right: 60,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.5))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.bedtime_rounded, color: Colors.orange, size: 13),
                  const SizedBox(width: 5),
                  Text(_sleepLabel,
                      style: const TextStyle(color: Colors.orange, fontSize: 12)),
                ]),
              ),
            ),

          // ── Skip intro ──
          if (_skipIntroVisible && !_locked && !_showNextEpisode)
            Positioned(
              bottom: 90, right: 20,
              child: GestureDetector(
                onTap: () {
                  _player.seek(const Duration(seconds: 85));
                  setState(() => _skipIntroVisible = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: Colors.white38)),
                  child: const Text('Skip Intro →',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(
                      begin: 0.3,
                      end: 0,
                      duration: 300.ms,
                      curve: AppCurves.standard),
            ),

          // ── Next Episode ──
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

          // ── Controls ──
          if (_showControls && !_longPressFast && !_showNextEpisode)
            _ControlsOverlay(
              title: _currentTitle,
              playing: _playing,
              buffering: _buffering,
              locked: _locked,
              position: _previewPosition,
              duration: _duration,
              progress: _sliderDragging
                  ? _sliderDragValue
                  : _progressFraction,
              speed: _speed,
              fitLabel: _fitLabel,
              hasNext: _hasNextEp,
              currentEp: widget.episodes != null ? _currentEpIdx : null,
              totalEps: widget.episodes?.length,
              sleepLabel: _sleepLabel,
              scale: _scale,
              isLocal: _isLocalFile,
              seekThumb: _seekThumb,
              sliderDragging: _sliderDragging,
              onBack: () => Navigator.of(context).pop(),
              onPlayPause: () {
                _player.playOrPause();
                _userPaused = !_playing;
              },
              onSeekTo: (frac) {
                final ms = (frac * _duration.inMilliseconds).toInt();
                _player.seek(Duration(milliseconds: ms));
                setState(() => _seekThumb = null);
              },
              onSliderStart: (v) {
                setState(() {
                  _sliderDragging = true;
                  _sliderDragValue = v;
                });
                _updateSeekThumb(v);
              },
              onSliderChange: (v) {
                setState(() => _sliderDragValue = v);
                _updateSeekThumb(v);
              },
              onSliderEnd: (v) {
                final ms = (v * _duration.inMilliseconds).toInt();
                _player.seek(Duration(milliseconds: ms));
                setState(() {
                  _sliderDragging = false;
                  _seekThumb = null;
                });
              },
              onSeekBack: () => _seekRelative(-10),
              onSeekForward: () => _seekRelative(10),
              onLock: () => setState(() {
                _locked = !_locked;
                _showControls = false;
              }),
              onCycleFit: _cycleFit,
              onSpeed: () => setState(() {
                _showSpeedPicker = !_showSpeedPicker;
                _scheduleHide();
              }),
              onSubtitleFile: _pickSubtitle,
              onSubtitleTracks: () =>
                  setState(() => _showSubtitleMenu = !_showSubtitleMenu),
              onAudioTracks: () =>
                  setState(() => _showAudioMenu = !_showAudioMenu),
              onNextEpisode: _hasNextEp ? _playNextEpisode : null,
              onPiP: _enterPiP,
              onCast: _enterCast,
              castConnected: _castConnected,
              onSleep: () => setState(() => _showSleepMenu = !_showSleepMenu),
              onResetZoom: _scale > 1.02
                  ? () => setState(() => _scale = 1.0)
                  : null,
              fmtDur: _fmtDur,
            ),

          // ── Lock Button ──
          if (_locked && _showControls)
            Positioned(
              right: 20, top: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _locked = false;
                    _showControls = true;
                    _scheduleHide();
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black54,
                        border: Border.all(color: Colors.white30)),
                    child: const Icon(Icons.lock_open_rounded,
                        color: Colors.white, size: 22)),
                ),
              ).animate().fadeIn(duration: 200.ms),
            ),

          // ── Speed Panel ──
          if (_showSpeedPicker && !_locked)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: _SpeedPanel(
                currentSpeed: _speed,
                speeds: _speeds,
                onSelect: (s) {
                  setState(() {
                    _speed = s;
                    _showSpeedPicker = false;
                  });
                  _player.setRate(s);
                  _scheduleHide();
                },
              ),
            ),

          // ── Subtitle Tracks ──
          if (_showSubtitleMenu && !_locked)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: _TracksPanel(
                title: 'Subtitles',
                tracks: _player.state.tracks.subtitle
                    .map((t) => t.language ?? t.id ?? 'Track')
                    .toList(),
                onSelect: (i) {
                  _player.setSubtitleTrack(
                      _player.state.tracks.subtitle[i]);
                  setState(() => _showSubtitleMenu = false);
                },
              ),
            ),

          // ── Audio Tracks ──
          if (_showAudioMenu && !_locked)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: _TracksPanel(
                title: 'Audio',
                tracks: _player.state.tracks.audio
                    .map((t) => t.language ?? t.id ?? 'Track')
                    .toList(),
                onSelect: (i) {
                  _player.setAudioTrack(_player.state.tracks.audio[i]);
                  setState(() => _showAudioMenu = false);
                },
              ),
            ),

          // ── Sleep Timer Menu ──
          if (_showSleepMenu && !_locked)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: _SleepPanel(
                remaining: _sleepRemainingSeconds,
                onSelect: (mins) {
                  _setSleepTimer(mins);
                  setState(() => _showSleepMenu = false);
                  _scheduleHide();
                },
                onCancel: () {
                  _cancelSleepTimer();
                  setState(() => _showSleepMenu = false);
                  _scheduleHide();
                },
              ),
            ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONTROLS OVERLAY
// ═══════════════════════════════════════════════════════════════════════════════

class _ControlsOverlay extends StatelessWidget {
  final String title;
  final bool playing, buffering, locked;
  final Duration position, duration;
  final double progress, speed, scale;
  final String fitLabel, sleepLabel;
  final bool hasNext, isLocal, sliderDragging;
  final int? currentEp, totalEps;
  final Uint8List? seekThumb;
  final VoidCallback onBack, onPlayPause, onSeekBack, onSeekForward;
  final VoidCallback onLock, onCycleFit, onSpeed;
  final VoidCallback onSubtitleFile, onSubtitleTracks, onAudioTracks;
  final VoidCallback onPiP, onSleep, onCast;
  final bool castConnected;
  final VoidCallback? onNextEpisode, onResetZoom;
  final ValueChanged<double> onSeekTo, onSliderStart, onSliderChange, onSliderEnd;
  final String Function(Duration) fmtDur;

  const _ControlsOverlay({
    required this.title, required this.playing, required this.buffering,
    required this.locked, required this.position, required this.duration,
    required this.progress, required this.speed, required this.fitLabel,
    required this.hasNext, required this.isLocal, required this.sliderDragging,
    required this.scale, required this.sleepLabel,
    this.seekThumb, this.currentEp, this.totalEps,
    required this.onBack, required this.onPlayPause, required this.onSeekBack,
    required this.onSeekForward, required this.onLock, required this.onCycleFit,
    required this.onSpeed, required this.onSubtitleFile, required this.onSubtitleTracks,
    required this.onAudioTracks, required this.onPiP, required this.onSleep,
    required this.onCast, required this.castConnected,
    this.onNextEpisode, this.onResetZoom,
    required this.onSeekTo, required this.onSliderStart,
    required this.onSliderChange, required this.onSliderEnd,
    required this.fmtDur,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Gradient scrim
      Positioned.fill(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
              stops: [0.0, 0.25, 0.75, 1.0],
            ),
          ),
        ),
      ),

      // ── TOP BAR ──
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
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
              // Zoom reset
              if (onResetZoom != null)
                _TopBtn(label: '${scale.toStringAsFixed(1)}×', onTap: onResetZoom!),
              _TopBtn(label: fitLabel, onTap: onCycleFit),
              _TopBtn(label: speed == 1.0 ? '1×' : '${speed}×', onTap: onSpeed),
              // Sleep timer button
              _TopIconBtn(
                icon: sleepLabel.isEmpty ? Icons.bedtime_outlined : Icons.bedtime_rounded,
                color: sleepLabel.isEmpty ? Colors.white : Colors.orange,
                badge: sleepLabel.isNotEmpty ? sleepLabel : null,
                onTap: onSleep,
                tooltip: 'Sleep Timer',
              ),
              // PiP button
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt_rounded,
                    color: Colors.white, size: 22),
                tooltip: 'Picture in Picture',
                onPressed: onPiP,
              ),
              // Chromecast button
              IconButton(
                icon: Icon(
                  castConnected ? Icons.cast_connected_rounded : Icons.cast_rounded,
                  color: castConnected ? const Color(0xFF4FC3F7) : Colors.white,
                  size: 22,
                ),
                tooltip: castConnected ? 'Stop Casting' : 'Cast to TV',
                onPressed: onCast,
              ),
              IconButton(icon: const Icon(Icons.subtitles_outlined, color: Colors.white, size: 22),
                  tooltip: 'Subtitles', onPressed: onSubtitleTracks),
              IconButton(icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 22),
                  tooltip: 'Audio', onPressed: onAudioTracks),
              IconButton(icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 22),
                  tooltip: 'Lock', onPressed: onLock),
            ]),
          ),
        ),
      ),

      // ── CENTER CONTROLS ──
      if (!locked)
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _SeekBtn(icon: Icons.replay_10_rounded, onTap: onSeekBack),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.9), boxShadow: AppShadows.glow),
              child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 38)),
          ),
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

      // ── BOTTOM BAR ──
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text(fmtDur(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(fmtDur(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 4),

            // Seek thumbnail preview
            if (seekThumb != null && (sliderDragging) && isLocal)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Align(
                  alignment: Alignment(progress * 2 - 1, 0),
                  child: Container(
                    width: 120, height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white38),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.memory(seekThumb!, fit: BoxFit.cover),
                  ),
                ),
              ),

            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: sliderDragging ? 4 : 3,
                thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: sliderDragging ? 8 : 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primaryGlow,
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChangeStart: onSliderStart,
                onChanged: onSliderChange,
                onChangeEnd: onSliderEnd,
              ),
            ),

            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 13, color: Colors.white54),
                label: const Text('Subtitle File',
                    style: TextStyle(color: Colors.white54, fontSize: 10)),
                onPressed: onSubtitleFile,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ]),
          ]).animate().fadeIn(duration: 200.ms),
        ),
      ),
    ]);
  }
}

// ─── Top icon button with optional badge ────────────────────────────────────
class _TopIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;
  final String tooltip;
  const _TopIconBtn({required this.icon, required this.color,
      this.badge, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: badge != null
            ? Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: 20),
                Text(badge!, style: TextStyle(color: color, fontSize: 9)),
              ])
            : Icon(icon, color: color, size: 22),
      ),
    );
  }
}

class _TopBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TopBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: Colors.black38, borderRadius: BorderRadius.circular(5)),
      child: Text(label, style: const TextStyle(
          color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))));
}

class _SeekBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SeekBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 50, height: 50,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
        child: Icon(icon, color: Colors.white, size: 28)));
}

// ═══════════════════════════════════════════════════════════════════════════════
// SLEEP PANEL
// ═══════════════════════════════════════════════════════════════════════════════
class _SleepPanel extends StatelessWidget {
  final int? remaining;
  final ValueChanged<int> onSelect;
  final VoidCallback onCancel;
  const _SleepPanel({this.remaining, required this.onSelect, required this.onCancel});

  static const _options = [
    (label: '5 minutes',  value: 5),
    (label: '10 minutes', value: 10),
    (label: '15 minutes', value: 15),
    (label: '30 minutes', value: 30),
    (label: '45 minutes', value: 45),
    (label: '1 hour',     value: 60),
    (label: '2 hours',    value: 120),
    (label: 'End of episode', value: -1),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180, color: Colors.black87,
      child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Icon(Icons.bedtime_rounded, color: Colors.orange, size: 18),
            SizedBox(width: 8),
            Text('Sleep Timer', style: TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          ])),
        if (remaining != null) ...[
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Stopping in ${remaining! ~/ 60}:${(remaining! % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.orange, fontSize: 12))),
          ListTile(dense: true,
            leading: const Icon(Icons.cancel_outlined, color: Colors.red, size: 18),
            title: const Text('Cancel Timer', style: TextStyle(color: Colors.red, fontSize: 13)),
            onTap: onCancel),
          const Divider(color: Colors.white12),
        ],
        Expanded(child: ListView(children: _options.map((o) => ListTile(
          dense: true,
          leading: const Icon(Icons.alarm, color: Colors.white54, size: 18),
          title: Text(o.label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          onTap: () => onSelect(o.value),
        )).toList())),
      ]),
    ).animate().slideX(begin: 1, end: 0, duration: 200.ms, curve: AppCurves.standard);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SPEED PANEL
// ═══════════════════════════════════════════════════════════════════════════════
class _SpeedPanel extends StatelessWidget {
  final double currentSpeed;
  final List<double> speeds;
  final ValueChanged<double> onSelect;
  const _SpeedPanel({required this.currentSpeed, required this.speeds, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Container(width: 140, color: Colors.black87,
      child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Speed', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        Expanded(child: ListView(children: speeds.map((s) => ListTile(
          title: Text('${s}×', style: TextStyle(
              color: s == currentSpeed ? AppColors.primary : Colors.white,
              fontWeight: s == currentSpeed ? FontWeight.w700 : FontWeight.normal)),
          leading: s == currentSpeed
              ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 18) : null,
          onTap: () => onSelect(s), dense: true)).toList())),
      ])).animate().slideX(begin: 1, end: 0, duration: 200.ms, curve: AppCurves.standard);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRACKS PANEL
// ═══════════════════════════════════════════════════════════════════════════════
class _TracksPanel extends StatelessWidget {
  final String title;
  final List<String> tracks;
  final ValueChanged<int> onSelect;
  const _TracksPanel({required this.title, required this.tracks, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Container(width: 180, color: Colors.black87,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        Expanded(child: tracks.isEmpty
            ? const Center(child: Text('No tracks', style: TextStyle(color: Colors.white54, fontSize: 13)))
            : ListView.builder(itemCount: tracks.length,
                itemBuilder: (_, i) => ListTile(
                    title: Text(tracks[i], style: const TextStyle(color: Colors.white)),
                    dense: true, onTap: () => onSelect(i)))),
      ])).animate().slideX(begin: 1, end: 0, duration: 200.ms, curve: AppCurves.standard);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SEEK FLASH
// ═══════════════════════════════════════════════════════════════════════════════
class _SeekFlash extends StatelessWidget {
  final bool isRight;
  final String label;
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
          Text(label, style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ])),
      ),
    ).animate().fadeIn(duration: 150.ms).then().fadeOut(duration: 400.ms, delay: 250.ms);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAG INDICATOR
// ═══════════════════════════════════════════════════════════════════════════════
class _DragIndicator extends StatelessWidget {
  final IconData icon;
  final double value;
  const _DragIndicator({required this.icon, required this.value});
  @override
  Widget build(BuildContext context) {
    return Center(child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(12)),
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

// ═══════════════════════════════════════════════════════════════════════════════
// NEXT EPISODE OVERLAY  (unchanged)
// ═══════════════════════════════════════════════════════════════════════════════
class _NextEpisodeOverlay extends StatelessWidget {
  final String currentTitle, nextTitle;
  final int countdown;
  final VoidCallback onPlay, onCancel, onSkipCountdown;
  const _NextEpisodeOverlay({
    required this.currentTitle, required this.nextTitle, required this.countdown,
    required this.onPlay, required this.onCancel, required this.onSkipCountdown,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.skip_next_rounded, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          const Text('Up Next', style: TextStyle(color: Colors.white54, fontSize: 14)),
          const SizedBox(height: 8),
          Text(nextTitle, style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Text('Playing in $countdown...', style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            TextButton(onPressed: onCancel,
              child: const Text('Exit', style: TextStyle(color: Colors.white54, fontSize: 15))),
            const SizedBox(width: 24),
            ElevatedButton(
              onPressed: onSkipCountdown,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: const Text('Play Now', style: TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
        ]),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}
