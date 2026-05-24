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
import '../providers/auth_provider.dart';
import '../services/api_client.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String title;
  final String? localPath;
  const PlayerScreen({super.key, required this.fileId, required this.title, this.localPath});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with TickerProviderStateMixin {
  late final Player _player;
  late final VideoController _videoCtrl;

  // Controls visibility
  bool _showControls  = true;
  Timer? _hideTimer;
  bool _locked        = false;

  // Seek flash state
  bool _showSeekLeft  = false;
  bool _showSeekRight = false;

  // Speed
  double _speed = 1.0;
  static const _speeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  // Gesture drag state
  double? _dragStartX;
  double? _dragStartY;
  double? _dragStartBrightness;
  double? _dragStartVolume;
  bool _draggingBrightness = false;
  bool _draggingVolume     = false;
  bool _draggingSeek       = false;
  double? _dragSeekOffset;   // seconds
  double _brightness = 0.5;
  double _volume     = 0.7;

  // Long press 2x speed
  bool _longPressFast = false;

  // UI
  bool _showSpeedPicker = false;
  bool _showSubtitleMenu= false;
  bool _showAudioMenu   = false;
  bool _skipIntroVisible= false;
  Timer? _skipIntroTimer;
  bool _pip = false;

  // Aspect ratio cycling
  final _ratios = [BoxFit.contain, BoxFit.cover, BoxFit.fill];
  int _ratioIdx = 0;

  // Chapter info (placeholder — extend with real data)
  Duration _position  = Duration.zero;
  Duration _duration  = Duration.zero;
  bool _buffering     = true;
  bool _playing       = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    WakelockPlus.enable();
    _initPlayer();
    _scheduleHide();
    _initBrightnessVolume();
  }

  Future<void> _initBrightnessVolume() async {
    try {
      _brightness = await ScreenBrightness().current;
      _volume = await VolumeController().getVolume();
    } catch (_) {}
  }

  Future<void> _initPlayer() async {
    _player   = Player();
    _videoCtrl = VideoController(_player);

    final token = await ref.read(authProvider.notifier).getAccessToken();
    final url   = widget.localPath != null
        ? widget.localPath!
        : '${AppConstants.apiBaseUrl}${ApiPaths.playUrl(widget.fileId)}?token=$token';

    await _player.open(Media(url));

    _player.stream.position.listen((p) { if (mounted) setState(() => _position = p); });
    _player.stream.duration.listen((d) { if (mounted) setState(() => _duration = d); });
    _player.stream.buffering.listen((b) { if (mounted) setState(() => _buffering = b); });
    _player.stream.playing.listen((p)  { if (mounted) setState(() => _playing = p); });

    // Show skip intro after 5 seconds of playback
    _skipIntroTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && _duration.inSeconds > 85) {
        setState(() => _skipIntroVisible = true);
        Timer(const Duration(seconds: 6), () {
          if (mounted) setState(() => _skipIntroVisible = false);
        });
      }
    });

    // Save watch history on dispose
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _skipIntroTimer?.cancel();
    _player.dispose();
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
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
    if (_locked) {
      setState(() => _showControls = !_showControls);
      if (_showControls) _scheduleHide();
      return;
    }
    setState(() => _showControls = !_showControls);
    if (_showControls) _scheduleHide();
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    _player.seek(target.clamp(Duration.zero, _duration));
    setState(() {
      if (seconds > 0) { _showSeekRight = true; }
      else             { _showSeekLeft  = true; }
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() { _showSeekLeft = false; _showSeekRight = false; });
    });
  }

  void _cycleFit() {
    setState(() => _ratioIdx = (_ratioIdx + 1) % _ratios.length);
  }

  String get _fitLabel {
    switch (_ratios[_ratioIdx]) {
      case BoxFit.contain: return 'Fit';
      case BoxFit.cover:   return 'Zoom';
      case BoxFit.fill:    return 'Stretch';
      default:             return 'Fit';
    }
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _progressFraction =>
      _duration.inMilliseconds > 0 ? _position.inMilliseconds / _duration.inMilliseconds : 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        onDoubleTapDown: (d) {
          final w = MediaQuery.of(context).size.width;
          if (d.localPosition.dx < w / 2) _seekRelative(-10);
          else _seekRelative(10);
        },
        onLongPressStart: (_) {
          setState(() { _longPressFast = true; });
          _player.setRate(2.0);
        },
        onLongPressEnd: (_) {
          setState(() { _longPressFast = false; });
          _player.setRate(_speed);
        },
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: (_) {
          setState(() { _draggingBrightness = false; _draggingVolume = false; });
        },
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Stack(children: [
          // VIDEO
          Positioned.fill(
            child: Video(controller: _videoCtrl,
                fit: _ratios[_ratioIdx], filterQuality: FilterQuality.medium)),

          // Seek flash overlays
          if (_showSeekLeft) _SeekFlash(side: false),
          if (_showSeekRight) _SeekFlash(side: true),

          // Buffering
          if (_buffering && _playing)
            const Center(child: SizedBox(width: 40, height: 40,
              child: CircularProgressIndicator(strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white70), strokeCap: StrokeCap.round))),

          // Drag indicators
          if (_draggingBrightness || _draggingVolume) _DragIndicator(
              icon: _draggingBrightness ? Icons.brightness_medium_rounded : Icons.volume_up_rounded,
              value: _draggingBrightness ? _brightness : _volume),

          // Long press speed
          if (_longPressFast)
            Positioned(top: 20, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54,
                    borderRadius: BorderRadius.circular(20)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.fast_forward_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text('2× Speed', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                ])))).animate().fadeIn(duration: 200.ms),

          // Skip intro
          if (_skipIntroVisible && !_locked)
            Positioned(bottom: 80, right: 24,
              child: GestureDetector(
                onTap: () {
                  _player.seek(const Duration(seconds: 85));
                  setState(() => _skipIntroVisible = false);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(color: Colors.black70,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(color: Colors.white38)),
                  child: const Text('Skip Intro →',
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                )).animate().fadeIn(duration: 300.ms)
                    .slideY(begin: 0.3, end: 0, duration: 300.ms, curve: AppCurves.standard)),

          // CONTROLS LAYER
          if (_showControls && !_longPressFast)
            _ControlsOverlay(
              title: widget.title,
              playing: _playing,
              buffering: _buffering,
              position: _position,
              duration: _duration,
              progress: _progressFraction,
              speed: _speed,
              locked: _locked,
              fitLabel: _fitLabel,
              onBack: () => Navigator.of(context).pop(),
              onPlayPause: () => _player.playOrPause(),
              onSeekTo: (frac) {
                final ms = (frac * _duration.inMilliseconds).toInt();
                _player.seek(Duration(milliseconds: ms));
              },
              onSeekBack: () => _seekRelative(-10),
              onSeekForward: () => _seekRelative(10),
              onLock: () { setState(() { _locked = !_locked; _showControls = false; }); },
              onCycleFit: _cycleFit,
              onSpeed: () => setState(() { _showSpeedPicker = !_showSpeedPicker; _scheduleHide(); }),
              onSubtitle: () => _pickSubtitle(),
              onSubtitleTracks: () => setState(() { _showSubtitleMenu = !_showSubtitleMenu; }),
              onAudioTracks: () => setState(() { _showAudioMenu = !_showAudioMenu; }),
              fmtDur: _fmtDur,
            ),

          // Lock indicator (when locked, show only unlock button)
          if (_locked && _showControls)
            Positioned(right: 20, top: 0, bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() { _locked = false; _showControls = true; _scheduleHide(); }),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black54,
                        border: Border.all(color: Colors.white30)),
                    child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 22)),
                )).animate().fadeIn(duration: 200.ms)),

          // Speed picker panel
          if (_showSpeedPicker && !_locked)
            Positioned(right: 0, top: 0, bottom: 0,
              child: _SpeedPanel(
                currentSpeed: _speed,
                speeds: _speeds,
                onSelect: (s) {
                  setState(() { _speed = s; _showSpeedPicker = false; });
                  _player.setRate(s);
                  _scheduleHide();
                },
              )),

          // Subtitle tracks panel
          if (_showSubtitleMenu && !_locked)
            Positioned(right: 0, top: 0, bottom: 0,
              child: _TracksPanel(
                title: 'Subtitles',
                tracks: _player.state.tracks.subtitle
                    .map((t) => t.language ?? t.id ?? 'Track').toList(),
                onSelect: (i) {
                  _player.setSubtitleTrack(_player.state.tracks.subtitle[i]);
                  setState(() => _showSubtitleMenu = false);
                },
              )),

          // Audio tracks panel
          if (_showAudioMenu && !_locked)
            Positioned(right: 0, top: 0, bottom: 0,
              child: _TracksPanel(
                title: 'Audio',
                tracks: _player.state.tracks.audio
                    .map((t) => t.language ?? t.id ?? 'Track').toList(),
                onSelect: (i) {
                  _player.setAudioTrack(_player.state.tracks.audio[i]);
                  setState(() => _showAudioMenu = false);
                },
              )),
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

  // ── Gesture Handlers ──────────────────────────────────────────────────────
  void _onVerticalDragStart(DragStartDetails d) {
    _dragStartX = d.localPosition.dx;
    _dragStartY = d.localPosition.dy;
    final w = MediaQuery.of(context).size.width;
    if (d.localPosition.dx < w / 2) {
      _draggingBrightness = true;
      _dragStartBrightness = _brightness;
    } else {
      _draggingVolume = true;
      _dragStartVolume = _volume;
    }
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
    _dragStartX = d.localPosition.dx;
    _draggingSeek = true;
    _dragSeekOffset = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (!_draggingSeek) return;
    final w = MediaQuery.of(context).size.width;
    final delta = d.delta.dx / w * 120; // 120 seconds across full width
    _dragSeekOffset = (_dragSeekOffset ?? 0) + delta;
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

// ── Controls Overlay ──────────────────────────────────────────────────────────
class _ControlsOverlay extends StatelessWidget {
  final String title;
  final bool playing, buffering, locked;
  final Duration position, duration;
  final double progress, speed;
  final String fitLabel;
  final VoidCallback onBack, onPlayPause, onSeekBack, onSeekForward,
      onLock, onCycleFit, onSpeed, onSubtitle, onSubtitleTracks, onAudioTracks;
  final ValueChanged<double> onSeekTo;
  final String Function(Duration) fmtDur;

  const _ControlsOverlay({
    required this.title, required this.playing, required this.buffering,
    required this.locked, required this.position, required this.duration,
    required this.progress, required this.speed, required this.fitLabel,
    required this.onBack, required this.onPlayPause, required this.onSeekBack,
    required this.onSeekForward, required this.onLock, required this.onCycleFit,
    required this.onSpeed, required this.onSubtitle, required this.onSubtitleTracks,
    required this.onAudioTracks, required this.onSeekTo, required this.fmtDur,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      // Scrim gradients
      const Positioned(top: 0, left: 0, right: 0, child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent])),
        child: SizedBox(height: 100))),
      const Positioned(bottom: 0, left: 0, right: 0, child: DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [Color(0xCC000000), Colors.transparent])),
        child: SizedBox(height: 120))),

      // TOP bar
      Positioned(top: 0, left: 0, right: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                onPressed: onBack),
            const SizedBox(width: 4),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
            // Fit button
            _TopBtn(label: fitLabel, onTap: onCycleFit),
            // Speed button
            _TopBtn(label: speed == 1.0 ? '1×' : '${speed}×', onTap: onSpeed),
            // Subtitle
            IconButton(icon: const Icon(Icons.subtitles_outlined, color: Colors.white, size: 22),
                onPressed: onSubtitleTracks),
            // Audio
            IconButton(icon: const Icon(Icons.audiotrack_rounded, color: Colors.white, size: 22),
                onPressed: onAudioTracks),
            // Lock
            IconButton(icon: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 22),
                onPressed: onLock),
          ]).animate().fadeIn(duration: 200.ms),
        )),

      // CENTER play controls (not shown when locked)
      if (!locked)
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(onTap: onSeekBack,
            child: Container(
              width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
              child: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 28))),
          const SizedBox(width: 28),
          GestureDetector(onTap: onPlayPause,
            child: Container(
              width: 64, height: 64,
              decoration: BoxDecoration(shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.9), boxShadow: AppShadows.glow),
              child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 38))),
          const SizedBox(width: 28),
          GestureDetector(onTap: onSeekForward,
            child: Container(
              width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
              child: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 28))),
        ]).animate().fadeIn(duration: 200.ms)),

      // BOTTOM bar
      Positioned(bottom: 0, left: 0, right: 0,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Time
            Row(children: [
              Text(fmtDur(position), style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Text(fmtDur(duration), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            // Progress bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: AppColors.primary,
                inactiveTrackColor: Colors.white24,
                thumbColor: AppColors.primary,
                overlayColor: AppColors.primaryGlow,
              ),
              child: Slider(value: progress.clamp(0.0, 1.0), onChanged: onSeekTo),
            ),
            // Subtitle load hint
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white60),
                label: const Text('Subtitle File', style: TextStyle(color: Colors.white60, fontSize: 11)),
                onPressed: onSubtitle,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ]),
          ]).animate().fadeIn(duration: 200.ms),
        )),
    ]);
  }
}

class _TopBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _TopBtn({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.black38,
            borderRadius: BorderRadius.circular(5)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

// ── Speed Panel ───────────────────────────────────────────────────────────────
class _SpeedPanel extends StatelessWidget {
  final double currentSpeed;
  final List<double> speeds;
  final ValueChanged<double> onSelect;
  const _SpeedPanel({required this.currentSpeed, required this.speeds, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      color: Colors.black87,
      child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Speed', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        Expanded(child: ListView(children: speeds.map((s) =>
          ListTile(
            title: Text('${s}×', style: TextStyle(
                color: s == currentSpeed ? AppColors.primary : Colors.white,
                fontWeight: s == currentSpeed ? FontWeight.w700 : FontWeight.normal)),
            leading: s == currentSpeed ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 18) : null,
            onTap: () => onSelect(s),
            dense: true,
          )).toList())),
      ]),
    ).animate().slideX(begin: 1, end: 0, duration: 200.ms, curve: AppCurves.standard);
  }
}

// ── Tracks Panel ──────────────────────────────────────────────────────────────
class _TracksPanel extends StatelessWidget {
  final String title;
  final List<String> tracks;
  final ValueChanged<int> onSelect;
  const _TracksPanel({required this.title, required this.tracks, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      color: Colors.black87,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
        Expanded(child: tracks.isEmpty
          ? const Center(child: Text('No tracks', style: TextStyle(color: Colors.white54, fontSize: 13)))
          : ListView.builder(itemCount: tracks.length, itemBuilder: (_, i) =>
              ListTile(title: Text(tracks[i], style: const TextStyle(color: Colors.white)),
                  dense: true, onTap: () => onSelect(i)))),
      ]),
    ).animate().slideX(begin: 1, end: 0, duration: 200.ms, curve: AppCurves.standard);
  }
}

// ── Seek Flash ────────────────────────────────────────────────────────────────
class _SeekFlash extends StatelessWidget {
  final bool side; // true = right, false = left
  const _SeekFlash({required this.side});
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Positioned(
      left: side ? w / 2 : 0,
      right: side ? 0 : w / 2,
      top: 0, bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: side ? Alignment.centerLeft : Alignment.centerRight,
            end:   side ? Alignment.centerRight : Alignment.centerLeft,
            colors: [Colors.white.withOpacity(0.08), Colors.transparent])),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(side ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
              color: Colors.white, size: 36),
          const SizedBox(height: 4),
          Text(side ? '+10s' : '-10s',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        ])),
      ),
    ).animate().fadeIn(duration: 150.ms).then().fadeOut(duration: 400.ms, delay: 300.ms);
  }
}

// ── Drag Indicator ────────────────────────────────────────────────────────────
class _DragIndicator extends StatelessWidget {
  final IconData icon;
  final double value;
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
          value: value,
          backgroundColor: Colors.white24,
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          minHeight: 3, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 6),
        Text('${(value * 100).toInt()}%',
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ]),
    ));
  }
}
