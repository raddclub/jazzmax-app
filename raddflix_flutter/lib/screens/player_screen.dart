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
import '../core/api/catalog_api.dart';
import '../core/services/jazzdrive_service.dart';
import '../core/debug/debug_logger.dart';
import '../core/player/player_prefs.dart';
import '../core/player/player_prefs_provider.dart';
import '../core/player/smart_intro_store.dart';
import '../core/player/ambilight_controller.dart';
import '../core/player/binge_guard_controller.dart';
import '../core/player/scene_bookmark_store.dart';
import '../core/player/ab_loop_controller.dart';
import '../widgets/player/sync_panel.dart';
import '../widgets/player/eq_panel.dart';
import '../widgets/player/quick_settings_panel.dart';
import '../widgets/player/ambilight_glow_border.dart';
import '../widgets/player/playback_info_overlay.dart';
import '../screens/player_settings_screen.dart';
import 'dart:math' as math;
import 'package:audio_session/audio_session.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import '../widgets/player/cinematic_overlay.dart';
import '../widgets/player/scene_bookmarks_panel.dart';
import '../widgets/player/ab_loop_panel.dart';
import '../widgets/player/track_badges.dart';
import '../widgets/player/video_enhance_panel.dart';
import '../widgets/player/transparent_player_layer.dart';

// ── PiP Method Channel ────────────────────────────────────────────────────────
const _pipChannel = MethodChannel('com.raddflix.app/pip');

class PlayerScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String title;
  final String? localPath;
  final List<Map<String, dynamic>>? episodes;
  final int episodeIndex;
  final String contentType; // 'series'|'drama'|'anime'|'movie'|'song'|etc.

  const PlayerScreen({
    super.key,
    required this.fileId,
    required this.title,
    this.localPath,
    this.episodes,
    this.episodeIndex = 0,
    this.contentType = 'series',
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
  bool _isLinkLoading = false;
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
  Duration _bufferedPosition = Duration.zero;

  // Position notifier — updates slider/time WITHOUT rebuilding full tree
  final _positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final _durationNotifier = ValueNotifier<Duration>(Duration.zero);

  // Sleep timer
  int? _sleepRemainingSeconds;
  Timer? _sleepTimer;
  // Sleep fade
  bool _sleepFadeActive = false;
  double _preFadeVolume = 0.7;
  Timer? _sleepFadeTimer;

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

  // JazzDrive XML auto-retry
  int _jazzRetryCount = 0;
  Timer? _jazzRetryTimer;
  String? _streamError;

  // Time display toggle (tap = elapsed/remaining)
  bool _showRemaining = false;

  // PlayerPrefs (loaded async — defaults used until ready)
  PlayerPrefs _prefs = const PlayerPrefs();

  // ── Phase 3B: Quick Settings / EQ panels ─────────────────────────────────
  bool _showQuickSettings = false;
  bool _showEqPanel = false;
  bool _showAudioSyncPanel = false;
  bool _showSubSyncPanel = false;

  // ── Phase 3C: Smart Skip Intro ────────────────────────────────────────────
  int? _savedIntroEnd; // seconds — loaded from SmartIntroStore

  // ── Phase 3D: Sync ────────────────────────────────────────────────────────
  int _audioDelayMs = 0;
  int _subDelayMs   = 0;

  // ── Phase 3G: Enhancement ────────────────────────────────────────────────
  double _volumeBoost = 1.0; // 1.0–3.0 = 100%–300%

  // ── Phase 3I: Ambilight ───────────────────────────────────────────────────
  AmbilightController? _ambilightCtrl;
  AmbilightColors _ambilightColors = const AmbilightColors();

  // ── Phase 3I: Binge Guard ─────────────────────────────────────────────────
  BingeGuardController? _bingeGuardCtrl;
  bool _showBingeGuard = false;
  int  _bingeWatchedMins = 0;

  // ── Phase 3I: Rage Skip ───────────────────────────────────────────────────
  bool  _rageSkipActive = false;
  int   _tapCount = 0;
  Timer? _tapTimer;

  // ── Phase 3I: Scene Bookmarks ─────────────────────────────────────────────
  List<SceneBookmark> _bookmarks = [];
  bool _showBookmarksPanel = false;

  // ── Phase 3K: A-B Loop ────────────────────────────────────────────────────
  final AbLoopController _abLoop = AbLoopController();
  bool _showAbPanel = false;

  // ── Phase 3K: Playback Info ───────────────────────────────────────────────
  bool _showPlaybackInfo = false;
  String _piCodec = '—', _piRes = '—', _piFps = '—',
         _piBitrate = '—', _piBuffer = '—', _piDecoder = 'HW';

  // ── Phase 3K: Frame Step ─────────────────────────────────────────────────
  bool _showFrameStep = false;

  // ── Phase 3F: Cinematic Mode ─────────────────────────────────────────────
  bool _cinematicMode = false;

  // ── Video Enhance / Transparent Slider ───────────────────────────────────
  bool _showVideoEnhance = false;
  bool _showTransparentSlider = false;

  // ── Track Intelligence ────────────────────────────────────────────────────
  int _activeAudioIdx = 0;
  int _activeSubIdx   = 0;

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
    _loadPrefs();
    _initAudioSession();
    _loadSmartIntro();
    _loadBookmarks();
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
      if (!_userPaused) {
        WakelockPlus.enable();
        // Seek back N seconds so user doesn't miss anything after switching apps
        final seekBack = _prefs.seekBackOnResumeSeconds;
        if (seekBack > 0 && _position.inSeconds > seekBack) {
          _player.seek(_position - Duration(seconds: seekBack));
        }
      }
    }
  }

  Future<void> _initBrightnessVolume() async {
    try {
      _brightness = await ScreenBrightness().current;
      _volume = await VolumeController().getVolume();
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    final loaded = await PlayerPrefs.load();
    if (!mounted) return;
    setState(() => _prefs = loaded);
    // Apply rotation mode from prefs
    _applyRotation(loaded.rotationMode);
    // Apply volume boost from prefs
    if (loaded.volumeBoostMultiplier > 1.0) _applyVolumeBoost(loaded.volumeBoostMultiplier);
    _volumeBoost = loaded.volumeBoostMultiplier;
    // Apply audio + video prefs
    _applyAudioPrefs(loaded);
    _applyVideoFilters(loaded);
    // Init binge guard + ambilight from prefs
    _initBingeGuard();
    _initAmbilight();
  }

  Future<void> _initAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.video());
      session.interruptionEventStream.listen((event) {
        if (!mounted) return;
        if (event.begin) {
          _player.pause();
        } else if (event.type == AudioInterruptionType.pause && !_userPaused) {
          _player.play();
        }
      });
      // Pause on headphone unplug
      session.becomingNoisyEventStream.listen((_) {
        if (mounted && !_userPaused) _player.pause();
      });
    } catch (_) {}
  }

  Future<void> _loadSmartIntro() async {
    if (!SmartIntroStore.shouldShow(
        contentType: widget.contentType,
        totalDuration: _duration)) return;
    final seriesId = widget.fileId.split('/').first;
    final end = await SmartIntroStore.getIntroEnd(
        seriesId: seriesId, epIndex: _currentEpIdx);
    if (mounted) setState(() => _savedIntroEnd = end);
  }

  Future<void> _loadBookmarks() async {
    final bm = await SceneBookmarkStore.getAll(
        contentId: widget.fileId,
        episodeId: widget.episodes != null ? _currentEpIdx.toString() : null);
    if (mounted) setState(() => _bookmarks = bm);
  }

  // Build MPV vf= filter string from prefs
  String _buildVfString(PlayerPrefs p) {
    final parts = <String>[];
    if (p.brightness != 0 || p.contrast != 0 || p.saturation != 0 || p.hue != 0) {
      parts.add('eq=brightness=${p.brightness}:contrast=${1 + p.contrast}'
          ':saturation=${1 + p.saturation}:hue=${p.hue / 180.0}');
    }
    if (p.nightMode) {
      final i = p.nightModeIntensity;
      parts.add('colorchannelmixer='
          'rr=${(0.9 + i * 0.05).toStringAsFixed(3)}'
          ':rg=${(0.1 * i).toStringAsFixed(3)}'
          ':rb=${(0.05 * i).toStringAsFixed(3)}'
          ':gr=${(0.01 * i).toStringAsFixed(3)}'
          ':gg=${(0.8 + i * 0.05).toStringAsFixed(3)}'
          ':gb=${(0.05 * i).toStringAsFixed(3)}'
          ':br=0:bg=0:bb=${(0.7 + i * 0.1).toStringAsFixed(3)}');
    }
    if (p.sharpnessEnabled) {
      parts.add('unsharp=la=${(p.sharpness * 2).toStringAsFixed(2)}'
          ':ca=${p.sharpness.toStringAsFixed(2)}');
    }
    return parts.join(',');
  }

  Future<void> _applyAudioPrefs(PlayerPrefs p) async {
    // Hardware decoder
    await _player.setProperty('hwdec', p.hwDecoderEnabled ? 'auto' : 'no');
    // Deinterlace
    await _player.setProperty('deinterlace', p.deinterlaceEnabled ? 'yes' : 'no');
    // Audio normalization
    if (p.audioNormalization) {
      await _player.setProperty('af', 'dynaudnorm');
    }
    // Equalizer bands
    if (p.equalizerEnabled && !p.dialogueBoostEnabled) {
      final b = p.equalizerBands;
      final eqStr = [60,170,310,600,1000,3000,6000,12000,14000,16000]
          .asMap().entries
          .map((e) => 'equalizer=f=${e.key < b.length ? [60,170,310,600,1000,3000,6000,12000,14000,16000][e.key] : 60}:width_type=o:width=2:g=${e.key < b.length ? b[e.key].toStringAsFixed(1) : "0"}')
          .join(',');
      await _player.setProperty('af', eqStr);
    } else if (p.dialogueBoostEnabled) {
      // Fixed voice-clarity EQ
      await _player.setProperty('af',
          'equalizer=f=310:width_type=o:width=2:g=2,'
          'equalizer=f=600:width_type=o:width=2:g=4,'
          'equalizer=f=1000:width_type=o:width=2:g=5,'
          'equalizer=f=3000:width_type=o:width=2:g=4,'
          'equalizer=f=6000:width_type=o:width=2:g=2');
    }
  }

  Future<void> _applyVideoFilters(PlayerPrefs p) async {
    final vf = _buildVfString(p);
    await _player.setProperty('vf', vf);
  }

  void _applyVolumeBoost(double multiplier) {
    _volumeBoost = multiplier;
    // Step 1: system volume to max
    VolumeController().setVolume(1.0);
    // Step 2: MPV internal amplification (100 = normal, 300 = 3×)
    _player.setProperty('volume', '${(multiplier * 100).toInt()}');
  }

  Future<void> _applyAudioSync(int ms) async {
    _audioDelayMs = ms;
    await _player.setProperty('audio-delay', '${ms / 1000.0}');
  }

  Future<void> _applySubSync(int ms) async {
    _subDelayMs = ms;
    await _player.setProperty('sub-delay', '${ms / 1000.0}');
  }

  Future<void> _fetchPlaybackInfo() async {
    try {
      final codec  = await _player.getProperty('video-codec');
      final width  = await _player.getProperty('width');
      final height = await _player.getProperty('height');
      final fps    = await _player.getProperty('fps');
      final bits   = await _player.getProperty('video-bitrate');
      final buf    = await _player.getProperty('demuxer-cache-duration');
      final hwdec  = await _player.getProperty('hwdec-current');
      if (!mounted) return;
      setState(() {
        _piCodec   = codec ?? '—';
        _piRes     = (width != null && height != null) ? '${width}×${height}' : '—';
        _piFps     = fps != null ? '${double.tryParse(fps)?.toStringAsFixed(1) ?? fps} fps' : '—';
        _piBitrate = bits != null ? '${(int.tryParse(bits) ?? 0) ~/ 1000} kbps' : '—';
        _piBuffer  = buf != null ? '${double.tryParse(buf)?.toStringAsFixed(1) ?? buf}s' : '—';
        _piDecoder = (hwdec != null && hwdec.isNotEmpty && hwdec != 'no') ? 'HW' : 'SW';
      });
    } catch (_) {}
  }

  /// Triple-tap center = Rage Skip
  void _handleCenterTap() {
    if (!_prefs.rageSkipEnabled) { _toggleControls(); return; }
    _tapCount++;
    _tapTimer?.cancel();
    if (_tapCount >= 3) {
      _tapCount = 0;
      final skipSecs = _prefs.rageSkipSeconds;
      _seekRelative(skipSecs);
      HapticFeedback.heavyImpact();
      setState(() => _rageSkipActive = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _rageSkipActive = false);
      });
    } else {
      _tapTimer = Timer(const Duration(milliseconds: 600), () {
        _tapCount = 0;
        _toggleControls();
      });
    }
  }

  void _shareTimestamp() {
    final pos = _fmtDur(_position);
    Share.share('Watching ${widget.title} at $pos on RaddFlix');
  }

  // ── Cinematic Mode ────────────────────────────────────────────────────────
  void _toggleCinematic() {
    setState(() => _cinematicMode = !_cinematicMode);
    if (_cinematicMode) setState(() => _showControls = false);
  }

  // ── Scene Bookmark ────────────────────────────────────────────────────────
  Future<void> _addBookmarkAtPosition() async {
    if (_duration == Duration.zero) return;
    final emoji = await showBookmarkEmojiPicker(context);
    if (emoji == null) return;
    await SceneBookmarkStore.add(
      contentId: widget.fileId,
      episodeId: widget.episodes != null ? _currentEpIdx.toString() : null,
      positionMs: _position.inMilliseconds,
      emoji: emoji,
    );
    await _loadBookmarks();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Bookmark $emoji added'), duration: const Duration(seconds: 2)));
  }

  Future<void> _deleteBookmark(int id) async {
    await SceneBookmarkStore.delete(id);
    await _loadBookmarks();
  }

  // ── Screenshot → Gallery ──────────────────────────────────────────────────
  Future<void> _takeScreenshot() async {
    try {
      final frame = await _player.screenshot();
      if (frame == null) return;
      await Gal.putImageBytes(frame, name: 'raddflix_${DateTime.now().millisecondsSinceEpoch}.jpg');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screenshot saved to gallery'),
            duration: Duration(seconds: 2)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save screenshot'),
            duration: Duration(seconds: 2)));
    }
  }

  Future<void> _showJumpToTime() async {
    final ctrl = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Jump to Timestamp',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Enter time as SS, MMSS, or HHMMSS',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                hintText: '4520 → 45:20',
                hintStyle: TextStyle(color: Colors.white38),
                border: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFE8002D))),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8002D)),
                  onPressed: () => Navigator.pop(context, ctrl.text),
                  child: const Text('Go', style: TextStyle(color: Colors.white)))),
            ]),
          ]),
        ),
      ),
    );
    if (result == null || result.isEmpty) return;
    final n = int.tryParse(result);
    if (n == null) return;
    Duration target;
    if (result.length <= 2) {
      target = Duration(seconds: n);
    } else if (result.length <= 4) {
      final m = n ~/ 100; final s = n % 100;
      target = Duration(minutes: m, seconds: s);
    } else {
      final h = n ~/ 10000; final m = (n % 10000) ~/ 100; final s = n % 100;
      target = Duration(hours: h, minutes: m, seconds: s);
    }
    _player.seek(target);
  }

  void _initBingeGuard() {
    _bingeGuardCtrl?.dispose();
    if (!_prefs.bingeGuardEnabled) return;
    _bingeGuardCtrl = BingeGuardController(
      thresholdMinutes: _prefs.bingeGuardThresholdMinutes,
      onThreshold: () {
        if (mounted) {
          _player.pause();
          setState(() {
            _showBingeGuard = true;
            _bingeWatchedMins = _bingeGuardCtrl?.watchedMinutes ?? 0;
          });
        }
      },
    );
  }

  void _initAmbilight() {
    _ambilightCtrl?.dispose();
    if (!_prefs.ambilightEnabled) return;
    _ambilightCtrl = AmbilightController(
      player: _player,
      intervalMs: _prefs.ambilightSampleIntervalMs,
      onUpdate: (colors) {
        if (mounted) setState(() => _ambilightColors = colors);
      },
    );
    _ambilightCtrl!.start();
  }

  void _applyRotation(String mode) {
    switch (mode) {
      case 'auto':
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
        break;
      case 'lock_left':
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
        break;
      case 'lock_right':
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
        break;
      case 'lock_portrait':
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        break;
      case 'lock_current':
        final mq = WidgetsBinding.instance.renderViews.first.flutterView.physicalSize;
        final isLandscape = mq.width > mq.height;
        SystemChrome.setPreferredOrientations(isLandscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp]);
        break;
      default: // 'sensor_landscape'
        SystemChrome.setPreferredOrientations(
          [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
    setState(() => _prefs = _prefs.copyWith(rotationMode: mode));
    _prefs.copyWith(rotationMode: mode).save();
  }

  void _cycleRotation() {
    const order = ['sensor_landscape', 'lock_left', 'lock_right', 'lock_portrait'];
    final idx = order.indexOf(_prefs.rotationMode);
    final next = order[(idx + 1) % order.length];
    _applyRotation(next);
    HapticFeedback.selectionClick();
  }

  /// Called when JazzDrive stream errors (XML page / expired token).
  /// Equivalent of "delete cookies + reload" in a browser.
  void _jazzAutoRetry(String reason) {
    if (_jazzRetryCount >= 1) {
      // Already retried once — show error overlay
      if (mounted) setState(() => _streamError = reason);
      return;
    }
    _jazzRetryCount++;
    if (mounted) {
      setState(() {
        _streamError = null;
        _isLinkLoading = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Refreshing video link…'),
        duration: Duration(seconds: 2),
      ));
    }
    // Wipe stale cached URL — forces fresh JazzDrive login + new CDN token
    JazzDriveService.invalidate(widget.fileId);
    _openMedia(widget.fileId);
  }
  double _brightness = 0.5;
  double _volume = 0.7;

  Future<void> _initPlayer() async {
    _player = Player();
    _videoCtrl = VideoController(_player);
    await _openMedia(widget.fileId, localPath: widget.localPath);

    _player.stream.position.listen((p) {
      if (!mounted) return;
      _position = p;
      _positionNotifier.value = p;
      // A-B Loop
      final seekBack = _abLoop.maybeSeekBack(p);
      if (seekBack != null) _player.seek(seekBack);
      if (p.inSeconds % 10 == 0 && _duration.inMilliseconds > 0) {
        LocalDb.saveWatchPosition(
            fileId: widget.fileId,
            positionMs: p.inMilliseconds,
            durationMs: _duration.inMilliseconds);
      }
      // Sleep countdown handled by _sleepTimer
    });
    _player.stream.duration.listen((d) {
      if (!mounted) return;
      _duration = d;
      _durationNotifier.value = d;
    });
    _player.stream.buffering.listen((b) {
      if (!mounted) return;
      setState(() => _buffering = b);
    });
    _player.stream.playing.listen((p) {
      if (!mounted) return;
      setState(() => _playing = p);
      if (p) { _bingeGuardCtrl?.onPlay(); }
      else   { _bingeGuardCtrl?.onPause(); }
    });
    _player.stream.buffer.listen((b) {
      if (!mounted) return;
      setState(() => _bufferedPosition = b);
    });
    _player.stream.completed.listen((done) {
      if (!mounted || !done) return;
      setState(() => _ended = true);
      _onPlaybackEnded();
    });

    // ── JazzDrive XML error detection ──────────────────────────────────────
    // Layer 1: MPV fires a hard error (expired token, DNS fail, etc.)
    _player.stream.error.listen((err) {
      if (!mounted || _isLocalFile) return;
      DebugLogger.logError('PLAYER', 'Stream error: $err');
      _jazzAutoRetry(err);
    });

    // Layer 2: Playing for 5s but duration is still zero → got XML instead of video
    _jazzRetryTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _isLocalFile || _jazzRetryCount > 0) return;
      if (_duration == Duration.zero && !_isLinkLoading) {
        DebugLogger.logError('PLAYER', 'Duration still zero after 5s — likely JazzDrive XML error');
        _jazzAutoRetry('Stream returned non-video content (possible XML error page)');
      }
    });

    // Smart skip intro: load saved position or show at 85s default
    _skipIntroTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      if (!SmartIntroStore.shouldShow(
          contentType: widget.contentType,
          totalDuration: _duration)) return;
      if (!_prefs.showSkipIntroButton) return;
      final seriesId = widget.fileId.split('/').first;
      final saved = await SmartIntroStore.getIntroEnd(
          seriesId: seriesId, epIndex: _currentEpIdx);
      setState(() { _savedIntroEnd = saved; });
      if (_duration.inSeconds > 60) {
        setState(() => _skipIntroVisible = true);
        if (_prefs.autoSkipIntroEnabled && saved != null) {
          _player.seek(Duration(seconds: saved));
          setState(() => _skipIntroVisible = false);
          return;
        }
        Timer(const Duration(seconds: 8), () {
          if (mounted) setState(() => _skipIntroVisible = false);
        });
      }
    });
  }

  Future<void> _openMedia(String fileId, {String? localPath}) async {
    // Local file: play directly
    if (localPath != null && localPath.isNotEmpty) {
      await _player.open(Media(localPath));
      setState(() { _ended = false; _position = Duration.zero; });
      return;
    }

    // Show loading indicator while resolving stream URL
    if (mounted) setState(() => _isLinkLoading = true);

    // Zero-rated path: on-device JazzDrive link generation
    // Works without internet bundle — Jazz SIM zero-rated access only
    final shareUrl = await LocalDb.getShareUrl(fileId);
    if (shareUrl != null && shareUrl.isNotEmpty) {
      try {
        final link = await JazzDriveService.getStreamLink(fileId, shareUrl);
        await _player.open(Media(link.streamUrl));
        setState(() { _ended = false; _position = Duration.zero; _isLinkLoading = false; });
        return;
      } catch (e) {
        DebugLogger.logError('PLAYER', 'JazzDrive link failed for $fileId', e);
        // Fall through to Oracle server fallback (keep _isLinkLoading=true)
      }
    }

    // Fallback: Oracle server stream URL (requires internet bundle)
    try {
      final url = await CatalogApi.getStreamUrl(fileId);
      await _player.open(Media(url));
      setState(() { _ended = false; _position = Duration.zero; _isLinkLoading = false; });
    } catch (e) {
      DebugLogger.logError('PLAYER', 'All stream methods failed for $fileId', e);
      if (mounted) {
        setState(() => _isLinkLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not load video. Check your connection.'),
        ));
      }
    }
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
    _skipIntroTimer = Timer(const Duration(seconds: 5), () async {
      if (!mounted) return;
      if (!SmartIntroStore.shouldShow(
          contentType: widget.contentType,
          totalDuration: _duration)) return;
      if (!_prefs.showSkipIntroButton) return;
      final seriesId = widget.fileId.split('/').first;
      final saved = await SmartIntroStore.getIntroEnd(
          seriesId: seriesId, epIndex: _currentEpIdx);
      if (!mounted) return;
      setState(() { _savedIntroEnd = saved; _skipIntroVisible = _duration.inSeconds > 60; });
      if (_prefs.autoSkipIntroEnabled && saved != null && _duration.inSeconds > 60) {
        _player.seek(Duration(seconds: saved));
        setState(() => _skipIntroVisible = false);
        return;
      }
      Timer(const Duration(seconds: 8), () {
        if (mounted) setState(() => _skipIntroVisible = false);
      });
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
  void _startSleepFade() {
    if (_sleepFadeActive) return;
    _sleepFadeActive = true;
    _preFadeVolume = _volume;
    final steps = _prefs.sleepFadeDurationSeconds.clamp(5, 120);
    var step = 0;
    _sleepFadeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || !_sleepFadeActive) { t.cancel(); return; }
      step++;
      final fraction = step / steps;
      final newVol = ((1.0 - fraction) * _preFadeVolume).clamp(0.0, 1.0);
      VolumeController().setVolume(newVol);
      _player.setProperty('volume', '${(newVol * _volumeBoost * 100).toInt()}');
      if (step >= steps) t.cancel();
    });
  }

  void _restoreVolumeAfterSleep() {
    _sleepFadeTimer?.cancel();
    _sleepFadeActive = false;
    VolumeController().setVolume(_preFadeVolume);
    _player.setProperty('volume', '${(_volumeBoost * 100).toInt()}');
  }

  void _setSleepTimer(int minutes) {
    _cancelSleepTimer();
    if (minutes <= 0) return;
    setState(() => _sleepRemainingSeconds = minutes * 60);
    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _sleepRemainingSeconds = (_sleepRemainingSeconds ?? 0) - 1;

        // Start volume fade when N seconds remain
        if (_prefs.sleepFadeEnabled &&
            !_sleepFadeActive &&
            _sleepRemainingSeconds! > 0 &&
            _sleepRemainingSeconds! <= _prefs.sleepFadeDurationSeconds) {
          _startSleepFade();
        }

        if (_sleepRemainingSeconds! <= 0) {
          t.cancel();
          _sleepRemainingSeconds = null;
          _restoreVolumeAfterSleep();
          _player.pause();
          _userPaused = true;
          setState(() => _showControls = true);
        }
      });
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepFadeTimer?.cancel();
    if (_sleepFadeActive) _restoreVolumeAfterSleep();
    _sleepFadeActive = false;
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
    final title = args?['title'] as String? ?? widget.title;
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
    _jazzRetryTimer?.cancel();
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
    _sleepFadeTimer?.cancel();
    _seekThumbDebounce?.cancel();
    _jazzRetryTimer?.cancel();
    _tapTimer?.cancel();
    _ambilightCtrl?.dispose();
    _bingeGuardCtrl?.dispose();
    if (_position.inMilliseconds > 0 && _duration.inMilliseconds > 0) {
      LocalDb.saveWatchPosition(
          fileId: widget.fileId,
          positionMs: _position.inMilliseconds,
          durationMs: _duration.inMilliseconds);
    }
    _positionNotifier.dispose();
    _durationNotifier.dispose();
    _player.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Restore full auto-rotate so system works normally after player exit
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    final secs = _prefs.autoHideSeconds;
    if (secs <= 0) return; // never auto-hide
    _hideTimer = Timer(Duration(seconds: secs), () {
      if (mounted &&
          !_showSpeedPicker &&
          !_showSubtitleMenu &&
          !_showAudioMenu &&
          !_showSleepMenu &&
          !_showQuickSettings &&
          !_showEqPanel &&
          !_showAudioSyncPanel &&
          !_showSubSyncPanel &&
          !_showAbPanel &&
          !_showBookmarksPanel &&
          !_showVideoEnhance) {
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
        onTap: _handleCenterTap,
        onDoubleTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          if (_scale > 1.01) {
            // Double-tap to reset zoom
            setState(() { _scale = 1.0; });
            return;
          }
          HapticFeedback.selectionClick();
          _seekRelative(d.localPosition.dx < w / 2 ? -15 : 15);
        },
        onLongPressStart: (_) {
          setState(() => _longPressFast = true);
          _player.setRate(_prefs.longPressSpeed);
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
                controls: NoVideoControls,
                subtitleViewConfiguration: const SubtitleViewConfiguration(visible: false),
              ),
            ),
          ),

          // ── Seek flash ──
          if (_showSeekLeft) _SeekFlash(isRight: false, label: _seekLabel),
          if (_showSeekRight) _SeekFlash(isRight: true, label: _seekLabel),

          // ── Buffering (accent color + pulse ring) ──
          if (_buffering && !_ended && _streamError == null)
            Center(
              child: SizedBox(
                width: 60, height: 60,
                child: Stack(alignment: Alignment.center, children: [
                  // Outer pulse ring
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE8002D).withOpacity(0.35),
                        width: 1.5)),
                  ).animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(1, 1), end: const Offset(1.45, 1.45),
                           duration: 900.ms, curve: Curves.easeOut)
                    .fadeOut(duration: 900.ms),
                  // Inner spinner
                  const SizedBox(
                    width: 36, height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      strokeCap: StrokeCap.round,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFE8002D))),
                  ),
                ]),
              ),
            ),

          // ── Stream error overlay ──
          if (_streamError != null)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFE8002D), size: 48),
                    const SizedBox(height: 16),
                    const Text('Could not load video',
                        style: TextStyle(color: Colors.white,
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('The video link may have expired.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withOpacity(0.65),
                            fontSize: 13)),
                    const SizedBox(height: 28),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      // Retry button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFE8002D),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: () {
                          setState(() { _streamError = null; _jazzRetryCount = 0; });
                          JazzDriveService.invalidate(widget.fileId);
                          _openMedia(widget.fileId);
                        },
                      ),
                      const SizedBox(width: 12),
                      // Back button
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: Colors.white24))),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      ),
                    ]),
                  ]),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),

          // ── Link loading (JazzDrive/Oracle URL resolution) ──
          if (_isLinkLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36, height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE8002D),
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('Loading…',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
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
              ).animate().fadeIn(duration: 150.ms, curve: Curves.easeOut),
            ),

          // ── Sleep fade badge ──
          if (_sleepFadeActive && _sleepRemainingSeconds != null)
            Positioned(
              top: 12, left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.orange.withOpacity(0.6), width: 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.bedtime_rounded, color: Colors.orange, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Sleeping in ${_sleepRemainingSeconds}s…',
                      style: const TextStyle(
                          color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ]),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                 .fadeIn(duration: 800.ms).then().fadeOut(duration: 800.ms),
              ),
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
                onTap: () async {
                  final seekTo = _savedIntroEnd ?? 85;
                  _player.seek(Duration(seconds: seekTo));
                  setState(() => _skipIntroVisible = false);
                  // Save for next time
                  final seriesId = widget.fileId.split('/').first;
                  await SmartIntroStore.saveIntroEnd(
                    seriesId: seriesId,
                    epIndex: _currentEpIdx,
                    positionSeconds: seekTo);
                },
              onLongPress: () async {
                  // Long-press: clear saved intro time
                  final seriesId = widget.fileId.split('/').first;
                  await SmartIntroStore.clearIntroEnd(
                    seriesId: seriesId, epIndex: _currentEpIdx);
                  setState(() { _savedIntroEnd = null; });
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cleared saved skip time'),
                        duration: Duration(seconds: 2)));
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
              bufferedFraction: _duration.inMilliseconds > 0
                  ? (_bufferedPosition.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0,
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
              onSeekBack: () => _seekRelative(-15),
              onSeekForward: () => _seekRelative(15),
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
              rotationMode: _prefs.rotationMode,
              onCycleRotation: _cycleRotation,
              audioDelayMs: _audioDelayMs,
              subDelayMs: _subDelayMs,
              volumeBoost: _volumeBoost,
              showPlaybackInfo: _showPlaybackInfo,
              onSettings: () => setState(() => _showQuickSettings = true),
              onEq: () => setState(() => _showEqPanel = true),
              onAudioSync: () => setState(() => _showAudioSyncPanel = true),
              onSubSync: () => setState(() => _showSubSyncPanel = true),
              onShareTimestamp: _shareTimestamp,
              onJumpToTime: _showJumpToTime,
              onTogglePlaybackInfo: () {
                setState(() => _showPlaybackInfo = !_showPlaybackInfo);
                if (_showPlaybackInfo) _fetchPlaybackInfo();
              },
              showRemaining: _showRemaining,
              onToggleRemaining: () => setState(() => _showRemaining = !_showRemaining),
              onNextEpisode: _hasNextEp ? _playNextEpisode : null,
              onPiP: _enterPiP,
              onCast: _enterCast,
              castConnected: _castConnected,
              onSleep: () => setState(() => _showSleepMenu = !_showSleepMenu),
              onResetZoom: _scale > 1.02
                  ? () => setState(() => _scale = 1.0)
                  : null,
              fmtDur: _fmtDur,
              cinematicMode: _cinematicMode,
              onToggleCinematic: _toggleCinematic,
              activeAudioIdx: _activeAudioIdx,
              activeSubIdx: _activeSubIdx,
              audioLabels: _buildAudioLabels(_player.state.tracks.audio),
              subLabels: _buildSubLabels(_player.state.tracks.subtitle),
              bookmarks: _bookmarks,
              abLoop: _abLoop,
              onToggleAbPanel: () => setState(() => _showAbPanel = !_showAbPanel),
              onToggleBookmarks: () => setState(() => _showBookmarksPanel = !_showBookmarksPanel),
              onToggleVideoEnhance: () => setState(() => _showVideoEnhance = !_showVideoEnhance),
              onTakeScreenshot: _takeScreenshot,
              onAddBookmark: _addBookmarkAtPosition,
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
              ).animate().fadeIn(duration: 150.ms, curve: Curves.easeOut),
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
                tracks: _buildSubLabels(_player.state.tracks.subtitle),
                activeIndex: _activeSubIdx,
                onSelect: (i) {
                  setState(() { _activeSubIdx = i; _showSubtitleMenu = false; });
                  _player.setSubtitleTrack(_player.state.tracks.subtitle[i]);
                },
              ),
            ),

          // ── Audio Tracks ──
          if (_showAudioMenu && !_locked)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: _TracksPanel(
                title: 'Audio',
                tracks: _buildAudioLabels(_player.state.tracks.audio),
                activeIndex: _activeAudioIdx,
                onSelect: (i) {
                  setState(() { _activeAudioIdx = i; _showAudioMenu = false; });
                  _player.setAudioTrack(_player.state.tracks.audio[i]);
                },
              ),
            ),

          // ── Rage Skip Badge ──
          if (_rageSkipActive)
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(color: Colors.red.withOpacity(0.22)).animate()
                  .fadeIn(duration: 50.ms).then(delay: 150.ms).fadeOut(duration: 200.ms),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.88),
                    borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'RAGE SKIP ⚡ +${(_prefs.rageSkipSeconds ~/ 60)}:00',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                ).animate()
                  .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.1, 1.1), duration: 250.ms, curve: Curves.elasticOut)
                  .then().scale(end: const Offset(1.0, 1.0), duration: 100.ms)
                  .then(delay: 600.ms).fadeOut(duration: 300.ms),
              ]),
            ),

          // ── Binge Guard overlay ──
          if (_showBingeGuard)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.88),
                child: Center(child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.health_and_safety_outlined, color: Color(0xFFE8002D), size: 52),
                    const SizedBox(height: 16),
                    const Text('Time for a Break!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text('You've watched $_bingeWatchedMins minutes in this session.',
                        style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TextButton(
                        onPressed: () { setState(() => _showBingeGuard = false); _player.play(); _bingeGuardCtrl?.reset(); },
                        style: TextButton.styleFrom(foregroundColor: Colors.white54),
                        child: const Text('Keep Watching')),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE8002D),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
                        child: const Text('Take a Break', style: TextStyle(color: Colors.white))),
                    ]),
                  ]),
                )),
              ).animate().fadeIn(duration: 300.ms),
            ),

          // ── Volume Boost badge ──
          if (_volumeBoost > 1.01 && !_showControls)
            Positioned(
              top: 16, left: 12,
              child: GestureDetector(
                onTap: () => setState(() => _showQuickSettings = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _volumeBoost > 2.5 ? Colors.red.withOpacity(0.5) : _volumeBoost > 1.5 ? Colors.orange.withOpacity(0.5) : Colors.white24)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.volume_up_rounded, size: 12,
                      color: _volumeBoost > 2.5 ? Colors.red : _volumeBoost > 1.5 ? Colors.orange : Colors.white),
                    const SizedBox(width: 4),
                    Text('${(_volumeBoost * 100).toInt()}%',
                      style: TextStyle(
                        color: _volumeBoost > 2.5 ? Colors.red : _volumeBoost > 1.5 ? Colors.orange : Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),

          // ── Playback Info overlay ──
          if (_showPlaybackInfo && !_showControls)
            PlaybackInfoOverlay(
              codec: _piCodec, resolution: _piRes, fps: _piFps,
              bitrate: _piBitrate, buffer: _piBuffer, decoder: _piDecoder),

          // ── Quick Settings bottom sheet trigger (overlay) ──
          if (_showQuickSettings)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showQuickSettings = false),
                child: Container(color: Colors.black45),
              ),
            ),
          if (_showQuickSettings)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: QuickSettingsPanel(
                prefs: _prefs,
                onChanged: (newPrefs) {
                  setState(() => _prefs = newPrefs);
                  newPrefs.save();
                  // Apply live changes
                  if (newPrefs.volumeBoostMultiplier != _prefs.volumeBoostMultiplier) {
                    _applyVolumeBoost(newPrefs.volumeBoostMultiplier);
                  }
                  _applyVideoFilters(newPrefs);
                  _applyAudioPrefs(newPrefs);
                  _initAmbilight();
                  _initBingeGuard();
                },
                onDone: () => setState(() => _showQuickSettings = false),
                onOpenFullSettings: () {
                  setState(() => _showQuickSettings = false);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const PlayerSettingsScreen()));
                },
                subDelayMs: _subDelayMs,
                audioDelayMs: _audioDelayMs,
                onSubDelay: (ms) => _applySubSync(ms),
                onAudioDelay: (ms) => _applyAudioSync(ms),
                onOpenSubSync: () {
                  setState(() { _showQuickSettings = false; _showSubSyncPanel = true; });
                },
                onOpenAudioSync: () {
                  setState(() { _showQuickSettings = false; _showAudioSyncPanel = true; });
                },
                speed: _speed,
                onSpeedChanged: (s) {
                  setState(() => _speed = s);
                  _player.setRate(s);
                },
              ),
            ),

          // ── Audio Sync Panel ──
          if (_showAudioSyncPanel)
            Positioned.fill(child: GestureDetector(
              onTap: () => setState(() => _showAudioSyncPanel = false),
              child: Container(color: Colors.black45))),
          if (_showAudioSyncPanel)
            Positioned(bottom: 0, left: 0, right: 0,
              child: SyncPanel(
                label: 'Audio',
                delayMs: _audioDelayMs,
                onChanged: _applyAudioSync,
                onDone: () => setState(() => _showAudioSyncPanel = false),
              )),

          // ── Subtitle Sync Panel ──
          if (_showSubSyncPanel)
            Positioned.fill(child: GestureDetector(
              onTap: () => setState(() => _showSubSyncPanel = false),
              child: Container(color: Colors.black45))),
          if (_showSubSyncPanel)
            Positioned(bottom: 0, left: 0, right: 0,
              child: SyncPanel(
                label: 'Subtitle',
                delayMs: _subDelayMs,
                onChanged: _applySubSync,
                onDone: () => setState(() => _showSubSyncPanel = false),
              )),

          // ── EQ Panel ──
          if (_showEqPanel)
            Positioned.fill(child: GestureDetector(
              onTap: () => setState(() => _showEqPanel = false),
              child: Container(color: Colors.black45))),
          if (_showEqPanel)
            Positioned(bottom: 0, left: 0, right: 0,
              child: EqPanel(
                prefs: _prefs,
                onChanged: (newPrefs) {
                  setState(() => _prefs = newPrefs);
                  newPrefs.save();
                  _applyAudioPrefs(newPrefs);
                },
                onDone: () => setState(() => _showEqPanel = false),
              )),

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

          // ── Cinematic Mode Overlay ──
          if (_cinematicMode)
            Positioned.fill(
              child: CinematicOverlay(
                isPlaying: _playing,
                position: _position,
                duration: _duration,
                fmtDur: _fmtDur,
                onPlayPause: () {
                  _player.playOrPause();
                  _userPaused = !_playing;
                },
                onExit: _toggleCinematic,
                onSeekTo: (frac) {
                  final ms = (frac * _duration.inMilliseconds).toInt();
                  _player.seek(Duration(milliseconds: ms));
                },
              ),
            ),

          // ── Scene Bookmarks Panel ──
          if (_showBookmarksPanel)
            Positioned.fill(child: GestureDetector(
              onTap: () => setState(() => _showBookmarksPanel = false),
              child: Container(color: Colors.black45))),
          if (_showBookmarksPanel)
            Positioned(bottom: 0, left: 0, right: 0,
              child: SceneBookmarksPanel(
                bookmarks: _bookmarks,
                fmtDur: _fmtDur,
                onSeekTo: (pos) => _player.seek(pos),
                onDelete: _deleteBookmark,
                onClose: () => setState(() => _showBookmarksPanel = false),
              )),

          // ── A-B Loop Panel ──
          if (_showAbPanel)
            Positioned.fill(child: GestureDetector(
              onTap: () => setState(() => _showAbPanel = false),
              child: Container(color: Colors.black45))),
          if (_showAbPanel)
            Positioned(bottom: 0, left: 0, right: 0,
              child: AbLoopPanel(
                controller: _abLoop,
                currentPosition: _position,
                fmtDur: _fmtDur,
                onChanged: () => setState(() {}),
                onClose: () => setState(() => _showAbPanel = false),
              )),

          // ── Video Enhancement Panel ──
          if (_showVideoEnhance)
            Positioned.fill(child: GestureDetector(
              onTap: () => setState(() => _showVideoEnhance = false),
              child: Container(color: Colors.black45))),
          if (_showVideoEnhance)
            Positioned(bottom: 0, left: 0, right: 0,
              child: VideoEnhancePanel(
                prefs: _prefs,
                onChanged: (newPrefs) {
                  setState(() => _prefs = newPrefs);
                  newPrefs.save();
                  _applyVideoFilters(newPrefs);
                },
                onClose: () => setState(() => _showVideoEnhance = false),
              )),

          // ── Transparent Mode Opacity Slider ──
          if (_prefs.transparentModeEnabled && _showTransparentSlider)
            TransparentPlayerSlider(
              opacity: _prefs.transparentModeOpacity,
              onChanged: (v) {
                final np = _prefs.copyWith(transparentModeOpacity: v);
                setState(() => _prefs = np);
                np.save();
              },
              onClose: () => setState(() => _showTransparentSlider = false),
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
  final double bufferedFraction;
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
  final String rotationMode;
  final VoidCallback onCycleRotation;
  final int audioDelayMs;
  final int subDelayMs;
  final double volumeBoost;
  final bool showPlaybackInfo;
  final bool showRemaining;
  final VoidCallback onSettings;
  final VoidCallback onEq;
  final VoidCallback onAudioSync;
  final VoidCallback onSubSync;
  final VoidCallback onShareTimestamp;
  final VoidCallback onJumpToTime;
  final VoidCallback onToggleRemaining;
  final VoidCallback onTogglePlaybackInfo;
  final VoidCallback? onNextEpisode, onResetZoom;
  final ValueChanged<double> onSeekTo, onSliderStart, onSliderChange, onSliderEnd;
  final String Function(Duration) fmtDur;
  // Extended params
  final bool cinematicMode;
  final VoidCallback onToggleCinematic;
  final int activeAudioIdx;
  final int activeSubIdx;
  final List<String> audioLabels;
  final List<String> subLabels;
  final List<SceneBookmark> bookmarks;
  final AbLoopController abLoop;
  final VoidCallback onToggleAbPanel;
  final VoidCallback onToggleBookmarks;
  final VoidCallback onToggleVideoEnhance;
  final VoidCallback onTakeScreenshot;
  final VoidCallback onAddBookmark;

  const _ControlsOverlay({
    required this.title, required this.playing, required this.buffering,
    required this.bufferedFraction,
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
    required this.rotationMode, required this.onCycleRotation,
    this.audioDelayMs = 0, this.subDelayMs = 0,
    this.volumeBoost = 1.0, this.showPlaybackInfo = false,
    this.showRemaining = false,
    required this.onSettings, required this.onEq,
    required this.onAudioSync, required this.onSubSync,
    required this.onShareTimestamp, required this.onJumpToTime,
    required this.onToggleRemaining, required this.onTogglePlaybackInfo,
    this.onNextEpisode, this.onResetZoom,
    required this.onSeekTo, required this.onSliderStart,
    required this.onSliderChange, required this.onSliderEnd,
    required this.fmtDur,
    this.cinematicMode = false,
    required this.onToggleCinematic,
    this.activeAudioIdx = 0,
    this.activeSubIdx = 0,
    this.audioLabels = const [],
    this.subLabels = const [],
    this.bookmarks = const [],
    required this.abLoop,
    required this.onToggleAbPanel,
    required this.onToggleBookmarks,
    required this.onToggleVideoEnhance,
    required this.onTakeScreenshot,
    required this.onAddBookmark,
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
              // Active track pills
              if (audioLabels.isNotEmpty)
                AudioTrackBadge(
                  label: activeAudioIdx < audioLabels.length ? audioLabels[activeAudioIdx] : '',
                  onTap: onAudioTracks),
              SubTrackBadge(
                label: subLabels.isEmpty ? 'Off' : (activeSubIdx < subLabels.length ? subLabels[activeSubIdx] : 'Off'),
                isOff: subLabels.isEmpty,
                onTap: onSubtitleTracks),
              TrackCountBadge(audioCount: audioLabels.length, subCount: subLabels.length),
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
              IconButton(
                icon: Icon(_rotationIcon(rotationMode), color: Colors.white, size: 22),
                tooltip: _rotationLabel(rotationMode),
                onPressed: onCycleRotation,
              ),
              // EQ button
              IconButton(
                icon: const Icon(Icons.equalizer_rounded, color: Colors.white, size: 22),
                tooltip: 'Equalizer',
                onPressed: onEq,
              ),
              // Video Enhancement
              IconButton(
                icon: const Icon(Icons.brightness_6_rounded, color: Colors.white, size: 20),
                tooltip: 'Video Enhancement',
                onPressed: onToggleVideoEnhance,
              ),
              // Cinematic Mode
              IconButton(
                icon: Icon(Icons.crop_free_rounded,
                    color: cinematicMode ? const Color(0xFFE8002D) : Colors.white, size: 20),
                tooltip: cinematicMode ? 'Exit Cinematic' : 'Cinematic Mode',
                onPressed: onToggleCinematic,
              ),
              // Screenshot
              IconButton(
                icon: const Icon(Icons.screenshot_monitor_rounded, color: Colors.white, size: 20),
                tooltip: 'Screenshot to Gallery',
                onPressed: onTakeScreenshot,
              ),
              // A-B Loop
              IconButton(
                icon: Icon(Icons.loop_rounded,
                    color: abLoop.isActive ? const Color(0xFFE8002D) : Colors.white, size: 20),
                tooltip: 'A-B Loop',
                onPressed: onToggleAbPanel,
              ),
              // Bookmarks
              IconButton(
                icon: Icon(Icons.bookmark_border_rounded,
                    color: bookmarks.isNotEmpty ? Colors.amber : Colors.white, size: 20),
                tooltip: 'Scene Bookmarks',
                onPressed: onToggleBookmarks,
              ),
              // Settings button
              IconButton(
                icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                tooltip: 'Player Settings',
                onPressed: onSettings,
              ),
              // Audio sync badge (tap to open sync panel; shows when delay ≠ 0)
              if (audioDelayMs != 0)
                GestureDetector(
                  onTap: onAudioSync,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x33E8002D),
                      border: Border.all(color: const Color(0xFFE8002D), width: 0.8),
                      borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      'Audio ${audioDelayMs > 0 ? '+' : ''}${audioDelayMs}ms ↺',
                      style: const TextStyle(color: Color(0xFFE8002D), fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
              // Sub sync badge
              if (subDelayMs != 0)
                GestureDetector(
                  onTap: onSubSync,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x33E8002D),
                      border: Border.all(color: const Color(0xFFE8002D), width: 0.8),
                      borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      'Sub ${subDelayMs > 0 ? '+' : ''}${subDelayMs}ms ↺',
                      style: const TextStyle(color: Color(0xFFE8002D), fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ),
        ),
      ),

      // ── CENTER CONTROLS ──
      if (!locked)
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          _SeekBtn(icon: Icons.replay_rounded, label: '15', onTap: onSeekBack),
          const SizedBox(width: 24),
          GestureDetector(
            onTap: onPlayPause,
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: AppColors.primary, boxShadow: AppShadows.glow),
              child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 42)),
          ),
          const SizedBox(width: 24),
          _SeekBtn(icon: Icons.forward_rounded, label: '15', onTap: onSeekForward),
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
        ]).animate().fadeIn(duration: 150.ms, curve: Curves.easeOut)),

      // ── BOTTOM BAR ──
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              GestureDetector(
                onTap: onToggleRemaining,
                onLongPress: onJumpToTime,
                child: Text(
                  showRemaining
                      ? '-${fmtDur(duration - position)}'
                      : fmtDur(position),
                  style: const TextStyle(color: Colors.white70, fontSize: 12))),
              const Spacer(),
              GestureDetector(
                onLongPress: onShareTimestamp,
                child: Text(fmtDur(duration),
                  style: const TextStyle(color: Colors.white70, fontSize: 12))),
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

            SizedBox(
              height: sliderDragging ? 44 : 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // ── Scene Bookmark dots ──
                  ...bookmarks.map((bm) {
                    if (duration.inMilliseconds <= 0) return const SizedBox.shrink();
                    final frac = (bm.positionMs / duration.inMilliseconds).clamp(0.0, 1.0);
                    return Positioned(
                      left: 24 + frac * (MediaQuery.of(context).size.width - 80),
                      top: 0, bottom: 0,
                      child: Center(child: GestureDetector(
                        onTap: () => onSeekTo(frac),
                        child: Text(bm.emoji, style: const TextStyle(fontSize: 10)))),
                    );
                  }),
                  // ── A-B loop dots ──
                  if (abLoop.pointA != null && duration.inMilliseconds > 0)
                    Positioned(
                      left: 24 + (abLoop.pointA!.inMilliseconds / duration.inMilliseconds).clamp(0.0,1.0) * (MediaQuery.of(context).size.width - 80),
                      top: 0, bottom: 0,
                      child: Center(child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.orange)))),
                  if (abLoop.pointB != null && duration.inMilliseconds > 0)
                    Positioned(
                      left: 24 + (abLoop.pointB!.inMilliseconds / duration.inMilliseconds).clamp(0.0,1.0) * (MediaQuery.of(context).size.width - 80),
                      top: 0, bottom: 0,
                      child: Center(child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE8002D))))),
                  // ── Buffer (gray) bar behind progress ──
                  Positioned(
                    left: 24, right: 24,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bufferedFraction.clamp(0.0, 1.0),
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white30),
                        minHeight: sliderDragging ? 5 : 3,
                      ),
                    ),
                  ),
                  // ── Progress (red) slider — transparent inactive track ──
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: sliderDragging ? 5 : 3,
                      thumbShape: RoundSliderThumbShape(
                          enabledThumbRadius: sliderDragging ? 10 : 5),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
                      activeTrackColor: AppColors.primary,
                      inactiveTrackColor: Colors.transparent,
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
                ],
              ),
            ),

            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                icon: const Icon(Icons.bookmark_add_outlined, size: 13, color: Colors.white54),
                label: const Text('Bookmark',
                    style: TextStyle(color: Colors.white54, fontSize: 10)),
                onPressed: onAddBookmark,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
              const SizedBox(width: 10),
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
          ]).animate().fadeIn(duration: 150.ms, curve: Curves.easeOut),
        ),
      ),
    ]);
  }
}

// ─── Top icon button with optional badge ────────────────────────────────────
// ── Rotation helpers ────────────────────────────────────────────────────────

IconData _rotationIcon(String mode) {
  switch (mode) {
    case 'lock_left':    return Icons.stay_current_landscape_rounded;
    case 'lock_right':   return Icons.stay_current_landscape_rounded;
    case 'lock_portrait': return Icons.stay_current_portrait_rounded;
    case 'auto':         return Icons.screen_rotation_outlined;
    case 'lock_current': return Icons.screen_lock_rotation_rounded;
    default:             return Icons.screen_rotation_rounded; // sensor_landscape
  }
}

String _rotationLabel(String mode) {
  switch (mode) {
    case 'lock_left':    return 'Locked: Landscape Left';
    case 'lock_right':   return 'Locked: Landscape Right';
    case 'lock_portrait': return 'Locked: Portrait';
    case 'auto':         return 'Auto Rotate';
    case 'lock_current': return 'Lock Current';
    default:             return 'Sensor Landscape'; // sensor_landscape
  }
}

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
  final String? label;
  final VoidCallback onTap;
  const _SeekBtn({required this.icon, required this.onTap, this.label});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: Container(width: 68, height: 68,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
        child: label != null
            ? Stack(alignment: Alignment.center, children: [
                Icon(icon, color: Colors.white, size: 30),
                Positioned(bottom: 13, child: Text(label!,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800))),
              ])
            : Icon(icon, color: Colors.white, size: 36)));
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


// ─── ISO 639 language code → human name ────────────────────────────────────
String _langName(String? code) {
  if (code == null || code.isEmpty) return '';
  const m = {
    'eng': 'English',  'en': 'English',
    'hin': 'Hindi',    'hi': 'Hindi',
    'urd': 'Urdu',     'ur': 'Urdu',
    'pan': 'Punjabi',  'pun': 'Punjabi', 'pa': 'Punjabi',
    'pus': 'Pashto',   'ps': 'Pashto',
    'snd': 'Sindhi',   'sd': 'Sindhi',
    'ara': 'Arabic',   'ar': 'Arabic',
    'per': 'Persian',  'fas': 'Persian', 'fa': 'Persian',
    'zho': 'Chinese',  'chi': 'Chinese', 'zh': 'Chinese',
    'kor': 'Korean',   'ko': 'Korean',
    'jpn': 'Japanese', 'ja': 'Japanese',
    'tam': 'Tamil',    'ta': 'Tamil',
    'tel': 'Telugu',   'te': 'Telugu',
    'mal': 'Malayalam','ml': 'Malayalam',
    'kan': 'Kannada',  'kn': 'Kannada',
    'ben': 'Bengali',  'bn': 'Bengali',
    'fre': 'French',   'fra': 'French', 'fr': 'French',
    'ger': 'German',   'deu': 'German', 'de': 'German',
    'spa': 'Spanish',  'es': 'Spanish',
    'ita': 'Italian',  'it': 'Italian',
    'rus': 'Russian',  'ru': 'Russian',
    'por': 'Portuguese','pt': 'Portuguese',
    'tur': 'Turkish',  'tr': 'Turkish',
    'und': '',
  };
  final key = code.toLowerCase().trim();
  return m[key] ?? (key.length <= 3 ? key.toUpperCase() : code);
}

List<String> _buildAudioLabels(List<dynamic> tracks) {
  final names = <String>[];
  final usedLangs = <String, int>{};
  for (var t in tracks) {
    final lang = _langName(t.language as String?);
    if (lang.isEmpty) {
      names.add('Audio ${names.length + 1}');
    } else {
      usedLangs[lang] = (usedLangs[lang] ?? 0) + 1;
      final count = usedLangs[lang]!;
      names.add(count == 1 ? lang : '$lang ($count)');
    }
  }
  return names;
}

List<String> _buildSubLabels(List<dynamic> tracks) {
  final names = <String>[];
  final usedLangs = <String, int>{};
  for (var t in tracks) {
    final lang = _langName(t.language as String?);
    final title = (t.title ?? '') as String;
    String label;
    if (lang.isNotEmpty) {
      usedLangs[lang] = (usedLangs[lang] ?? 0) + 1;
      final count = usedLangs[lang]!;
      label = count == 1 ? lang : '$lang ($count)';
    } else if (title.isNotEmpty) {
      label = title;
    } else {
      label = 'Sub ${names.length + 1}';
    }
    names.add(label);
  }
  return names;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRACKS PANEL
// ═══════════════════════════════════════════════════════════════════════════════
class _TracksPanel extends StatelessWidget {
  final String title;
  final List<String> tracks;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  const _TracksPanel({required this.title, required this.tracks, required this.onSelect, this.activeIndex = 0});
  @override
  Widget build(BuildContext context) {
    return Container(width: 200, color: Colors.black87,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        Expanded(child: tracks.isEmpty
            ? const Center(child: Text('No tracks', style: TextStyle(color: Colors.white54, fontSize: 13)))
            : ListView.builder(itemCount: tracks.length,
                itemBuilder: (_, i) {
                  final isActive = i == activeIndex;
                  return ListTile(
                    title: Text(tracks[i], style: TextStyle(
                      color: isActive ? const Color(0xFFE8002D) : Colors.white,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.normal)),
                    trailing: isActive
                      ? const Icon(Icons.check_rounded, color: Color(0xFFE8002D), size: 16)
                      : null,
                    dense: true, onTap: () => onSelect(i));
                })),
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
