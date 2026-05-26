import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/player/player_prefs.dart';
import '../../core/player/player_prefs_provider.dart';

class PlayerSettingsScreen extends ConsumerStatefulWidget {
  const PlayerSettingsScreen({super.key});
  @override
  ConsumerState<PlayerSettingsScreen> createState() => _PlayerSettingsScreenState();
}

class _PlayerSettingsScreenState extends ConsumerState<PlayerSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 10, vsync: this);
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _update(PlayerPrefs Function(PlayerPrefs p) fn) {
    ref.read(playerPrefsProvider.notifier).update(fn);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(playerPrefsProvider);
    const accent = Color(0xFFE8002D);

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0E1A),
        foregroundColor: Colors.white,
        title: const Text('Player Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A2E),
                  title: const Text('Reset Settings', style: TextStyle(color: Colors.white)),
                  content: const Text('All player settings will be reset to defaults.',
                      style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                        child: const Text('Reset', style: TextStyle(color: accent))),
                  ],
                ));
              if (confirm == true) ref.read(playerPrefsProvider.notifier).reset();
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white54, fontSize: 13)),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: Colors.white54,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Gestures'),
            Tab(text: 'Controls'),
            Tab(text: 'Rotation'),
            Tab(text: 'Subtitles'),
            Tab(text: 'Audio'),
            Tab(text: 'Video'),
            Tab(text: 'Features'),
            Tab(text: 'Playback'),
          Tab(text: 'Track Memory'),
          Tab(text: 'Appearance'),
          ],
        ),
      ),
      body: TabBarView(controller: _tab, children: [
        _GesturesTab(p: p, onChanged: _update),
        _ControlsTab(p: p, onChanged: _update),
        _RotationTab(p: p, onChanged: _update),
        _SubtitlesTab(p: p, onChanged: _update),
        _AudioTab(p: p, onChanged: _update),
        _VideoTab(p: p, onChanged: _update),
        _FeaturesTab(p: p, onChanged: _update),
        _PlaybackTab(p: p, onChanged: _update),
          _TrackMemoryTab(p: p, onChanged: _update),
          _AppearanceTab(p: p, onChanged: _update),
      ]),
    );
  }
}

// ── GESTURES TAB ─────────────────────────────────────────────────────────────
class _GesturesTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _GesturesTab({required this.p, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('Gesture Controls'),
    _Toggle('Enable Gestures', p.gestureEnabled,
        (v) => onChanged((x) => x.copyWith(gestureEnabled: v))),
    _Toggle('Swipe Brightness (Left side)', p.swipeBrightnessEnabled,
        (v) => onChanged((x) => x.copyWith(swipeBrightnessEnabled: v))),
    _Toggle('Swipe Volume (Right side)', p.swipeVolumeEnabled,
        (v) => onChanged((x) => x.copyWith(swipeVolumeEnabled: v))),
    _Toggle('Swipe Seek (Horizontal)', p.swipeSeekEnabled,
        (v) => onChanged((x) => x.copyWith(swipeSeekEnabled: v))),
    _Toggle('Pinch to Zoom', p.pinchZoomEnabled,
        (v) => onChanged((x) => x.copyWith(pinchZoomEnabled: v))),
    _Divider(),
    _Section('Double-Tap Seek'),
    _Toggle('Enable Double-Tap Seek', p.doubleTapSeekEnabled,
        (v) => onChanged((x) => x.copyWith(doubleTapSeekEnabled: v))),
    _Choices('Skip Duration', [5,10,15,20,30].map((s) => '$s s').toList(),
        [5,10,15,20,30].map((s) => s.toString()).toList(),
        p.doubleTapSeekSeconds.toString(),
        (v) => onChanged((x) => x.copyWith(doubleTapSeekSeconds: int.parse(v)))),
    _Divider(),
    _Section('Long Press Speed'),
    _Toggle('Enable Long-Press Speed', p.longPressSpeedEnabled,
        (v) => onChanged((x) => x.copyWith(longPressSpeedEnabled: v))),
    _Choices('Speed', ['1.5×','2.0×','2.5×','3.0×'], ['1.5','2.0','2.5','3.0'],
        p.longPressSpeed.toStringAsFixed(1),
        (v) => onChanged((x) => x.copyWith(longPressSpeed: double.parse(v)))),
    _Divider(),
    _Section('Sensitivity'),
    _SliderRow('Swipe Sensitivity', p.swipeSensitivity, 0.5, 2.0,
        (v) => onChanged((x) => x.copyWith(swipeSensitivity: v))),
    _SliderRow('Seek Sensitivity', p.seekSensitivity, 0.5, 2.0,
        (v) => onChanged((x) => x.copyWith(seekSensitivity: v))),
    _Divider(),
    _Section('Rage Skip ⚡'),
    _Toggle('Triple-Tap Rage Skip', p.rageSkipEnabled,
        (v) => onChanged((x) => x.copyWith(rageSkipEnabled: v))),
    _Choices('Skip Amount', ['1 min','2 min','3 min','5 min'], ['60','120','180','300'],
        p.rageSkipSeconds.toString(),
        (v) => onChanged((x) => x.copyWith(rageSkipSeconds: int.parse(v)))),
  ]);
}

// ── CONTROLS TAB ─────────────────────────────────────────────────────────────
class _ControlsTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _ControlsTab({required this.p, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('Controls Bar'),
    _SliderRow('Button Size', p.buttonSize, 0.8, 1.4,
        (v) => onChanged((x) => x.copyWith(buttonSize: v))),
    _SliderRow('Bar Opacity', p.controlBarOpacity, 0.3, 1.0,
        (v) => onChanged((x) => x.copyWith(controlBarOpacity: v))),
    _Divider(),
    _Section('Auto-Hide'),
    _Choices('Hide After', ['Never','2s','3s','5s','10s'], ['0','2','3','5','10'],
        p.autoHideSeconds.toString(),
        (v) => onChanged((x) => x.copyWith(autoHideSeconds: int.parse(v)))),
    _Divider(),
    _Section('Time Display'),
    _Toggle('Tap Time to Toggle Elapsed/Remaining', p.tapTimeToToggleRemaining,
        (v) => onChanged((x) => x.copyWith(tapTimeToToggleRemaining: v))),
    _Toggle('Show Buffer Bar', p.showBufferBar,
        (v) => onChanged((x) => x.copyWith(showBufferBar: v))),
  ]);
}

// ── ROTATION TAB ─────────────────────────────────────────────────────────────
class _RotationTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _RotationTab({required this.p, required this.onChanged});

  static const _modes = [
    ('sensor_landscape', Icons.screen_rotation_rounded, 'Sensor Landscape', 'Auto-rotates between left/right only (default)'),
    ('auto', Icons.screen_rotation_outlined, 'Full Auto', 'Follows device sensor in all directions'),
    ('lock_left', Icons.stay_current_landscape_rounded, 'Lock Landscape Left', 'Forces landscape-left orientation'),
    ('lock_right', Icons.stay_current_landscape_rounded, 'Lock Landscape Right', 'Forces landscape-right orientation'),
    ('lock_portrait', Icons.stay_current_portrait_rounded, 'Lock Portrait', 'Forces portrait orientation'),
    ('lock_current', Icons.screen_lock_rotation_rounded, 'Lock Current', 'Locks to whatever orientation is active now'),
  ];

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('Default Rotation Mode'),
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text('Controls how the player orients when you open a video.',
          style: TextStyle(color: Colors.white54, fontSize: 12)),
    ),
    ..._modes.map((m) => _RotationChoice(
      icon: m.$1 == 'lock_right'
          ? Transform.rotate(angle: math.pi, child: Icon(m.$2, color: p.rotationMode == m.$1 ? const Color(0xFFE8002D) : Colors.white54, size: 22))
          : Icon(m.$2, color: p.rotationMode == m.$1 ? const Color(0xFFE8002D) : Colors.white54, size: 22),
      title: m.$3,
      subtitle: m.$4,
      selected: p.rotationMode == m.$1,
      onTap: () => onChanged((x) => x.copyWith(rotationMode: m.$1)),
    )),
  ]);
}

class _RotationChoice extends StatelessWidget {
  final Widget icon;
  final String title, subtitle;
  final bool selected;
  final VoidCallback onTap;
  const _RotationChoice({required this.icon, required this.title, required this.subtitle, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    leading: icon,
    title: Text(title, style: TextStyle(color: selected ? const Color(0xFFE8002D) : Colors.white, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
    subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
    trailing: selected ? const Icon(Icons.check_circle_rounded, color: Color(0xFFE8002D), size: 20) : null,
    onTap: onTap,
  );
}

// ── SUBTITLES TAB ────────────────────────────────────────────────────────────
class _SubtitlesTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _SubtitlesTab({required this.p, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('General'),
    _Toggle('Enable Subtitles', p.subtitleEnabled,
        (v) => onChanged((x) => x.copyWith(subtitleEnabled: v))),
    _Toggle('Auto-Detect (Local Files)', p.subtitleAutoDetect,
        (v) => onChanged((x) => x.copyWith(subtitleAutoDetect: v))),
    _Divider(),
    _Section('Style'),
    _SliderRow('Font Size', p.subtitleFontSize, 10, 40,
        (v) => onChanged((x) => x.copyWith(subtitleFontSize: v)),
        unit: 'px', divisions: 30),
    _Choices('Font Family',
        ['Sans-Serif', 'Serif', 'Monospace', 'Cursive'],
        ['Sans-Serif', 'Serif', 'Monospace', 'Cursive'],
        p.subtitleFontFamily,
        (v) => onChanged((x) => x.copyWith(subtitleFontFamily: v))),
    _Toggle('Bold Text', p.subtitleBold,
        (v) => onChanged((x) => x.copyWith(subtitleBold: v))),
    _Toggle('Italic Text', p.subtitleItalic,
        (v) => onChanged((x) => x.copyWith(subtitleItalic: v))),
    _SliderRow('Outline Thickness', p.subtitleOutlineThickness, 0, 4,
        (v) => onChanged((x) => x.copyWith(subtitleOutlineThickness: v)),
        unit: '', divisions: 8),
    _SliderRow('Background Opacity', p.subtitleBackgroundOpacity, 0, 1,
        (v) => onChanged((x) => x.copyWith(subtitleBackgroundOpacity: v)),
        displayFn: (v) => '${(v*100).toInt()}%', divisions: 10),
    _Divider(),
    _Section('Position'),
    _Choices('Subtitle Position',
        ['Bottom', 'Center', 'Top'],
        ['bottom', 'center', 'top'],
        p.subtitlePosition,
        (v) => onChanged((x) => x.copyWith(subtitlePosition: v))),
    _SliderRow('Vertical Offset', p.subtitleVerticalOffset, -0.5, 0.5,
        (v) => onChanged((x) => x.copyWith(subtitleVerticalOffset: v)),
        displayFn: (v) => v.toStringAsFixed(2), divisions: 20),
    _Divider(),
    _Section('Encoding'),
    _Choices('Encoding Override',
        ['Auto', 'UTF-8', 'Latin-1', 'Windows-1252'],
        ['auto', 'utf-8', 'latin1', 'windows-1252'],
        p.subtitleEncoding,
        (v) => onChanged((x) => x.copyWith(subtitleEncoding: v))),
    _Divider(),
    _Section('Sync Default'),
    _SliderRow('Default Timing Offset', p.subtitleTimingOffsetMs.toDouble(), -2000, 2000,
        (v) => onChanged((x) => x.copyWith(subtitleTimingOffsetMs: v.toInt())),
        unit: 'ms', divisions: 80),
  ]);
}

// ── AUDIO TAB ────────────────────────────────────────────────────────────────
class _AudioTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _AudioTab({required this.p, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('Volume Boost'),
    _SliderRow('Boost Level', p.volumeBoostMultiplier, 1.0, 3.0,
        (v) => onChanged((x) => x.copyWith(volumeBoostMultiplier: v)),
        unit: '%', displayFn: (v) => '${(v*100).toInt()}%', divisions: 20),
    if (p.volumeBoostMultiplier > 2.0)
      const _WarningRow('⚠ May distort audio at 300%', Colors.red)
    else if (p.volumeBoostMultiplier > 1.5)
      const _WarningRow('⚠ High volume — use with caution', Colors.orange),
    _Divider(),
    _Section('Equalizer'),
    _Toggle('Enable Equalizer', p.equalizerEnabled,
        (v) => onChanged((x) => x.copyWith(equalizerEnabled: v))),
    _Toggle('Dialogue Boost (Voice Clarity)', p.dialogueBoostEnabled,
        (v) => onChanged((x) => x.copyWith(dialogueBoostEnabled: v))),
    _Toggle('Audio Normalization', p.audioNormalization,
        (v) => onChanged((x) => x.copyWith(audioNormalization: v))),
    _Divider(),
    _Section('Processing'),
    _Toggle('Deinterlace (for old TV recordings)', p.deinterlaceEnabled,
        (v) => onChanged((x) => x.copyWith(deinterlaceEnabled: v))),
    _Divider(),
    _Section('Track Intelligence'),
    _Toggle('Remember Audio Language', p.rememberAudioTrack,
        (v) => onChanged((x) => x.copyWith(rememberAudioTrack: v))),
    _Toggle('Auto-Select by Device Language', p.autoSelectAudioByLocale,
        (v) => onChanged((x) => x.copyWith(autoSelectAudioByLocale: v))),
    _Toggle('Show Active Track Badge', p.showActiveTrackBadge,
        (v) => onChanged((x) => x.copyWith(showActiveTrackBadge: v))),
    _Toggle('Show Track Count Badge', p.showTrackCountBadge,
        (v) => onChanged((x) => x.copyWith(showTrackCountBadge: v))),
    _Toggle('Remember Subtitle Language', p.rememberSubtitleTrack,
        (v) => onChanged((x) => x.copyWith(rememberSubtitleTrack: v))),
  ]);
}

// ── VIDEO TAB ────────────────────────────────────────────────────────────────
class _VideoTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _VideoTab({required this.p, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('Video Adjustments'),
    _SliderRow('Brightness', p.brightness, -0.5, 0.5,
        (v) => onChanged((x) => x.copyWith(brightness: v)), divisions: 20),
    _SliderRow('Contrast', p.contrast, -0.5, 0.5,
        (v) => onChanged((x) => x.copyWith(contrast: v)), divisions: 20),
    _SliderRow('Saturation', p.saturation, -0.5, 0.5,
        (v) => onChanged((x) => x.copyWith(saturation: v)), divisions: 20),
    _SliderRow('Hue', p.hue, -180, 180,
        (v) => onChanged((x) => x.copyWith(hue: v)), unit: '°', divisions: 72),
    _Divider(),
    _Section('Night Mode'),
    _Toggle('Night Mode', p.nightMode,
        (v) => onChanged((x) => x.copyWith(nightMode: v))),
    if (p.nightMode) _SliderRow('Intensity', p.nightModeIntensity, 0.1, 1.0,
        (v) => onChanged((x) => x.copyWith(nightModeIntensity: v)), divisions: 18),
    _Divider(),
    _Section('Sharpness'),
    _Toggle('Enable Sharpness', p.sharpnessEnabled,
        (v) => onChanged((x) => x.copyWith(sharpnessEnabled: v))),
    if (p.sharpnessEnabled) _SliderRow('Sharpness', p.sharpness, 0.0, 1.0,
        (v) => onChanged((x) => x.copyWith(sharpness: v)), divisions: 10),
  ]);
}

// ── FEATURES TAB ─────────────────────────────────────────────────────────────
class _FeaturesTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _FeaturesTab({required this.p, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('Ambilight ✨'),
    _Toggle('Ambilight Glow', p.ambilightEnabled,
        (v) => onChanged((x) => x.copyWith(ambilightEnabled: v))),
    if (p.ambilightEnabled) ...[
      _SliderRow('Intensity', p.ambilightIntensity, 0.3, 1.0,
          (v) => onChanged((x) => x.copyWith(ambilightIntensity: v)), divisions: 7),
      _Choices('Sample Rate', ['Fast (200ms)','Normal (400ms)','Smooth (800ms)'],
          ['200','400','800'], p.ambilightSampleIntervalMs.toString(),
          (v) => onChanged((x) => x.copyWith(ambilightSampleIntervalMs: int.parse(v)))),
    ],
    _Divider(),
    _Section('Transparent Player 👻'),
    _Toggle('Transparent Mode', p.transparentModeEnabled,
        (v) => onChanged((x) => x.copyWith(transparentModeEnabled: v))),
    if (p.transparentModeEnabled)
      _SliderRow('Opacity', p.transparentModeOpacity, 0.2, 1.0,
          (v) => onChanged((x) => x.copyWith(transparentModeOpacity: v)), divisions: 16),
    _Divider(),
    _Section('Binge Guard 🛡'),
    _Toggle('Binge Guard', p.bingeGuardEnabled,
        (v) => onChanged((x) => x.copyWith(bingeGuardEnabled: v))),
    if (p.bingeGuardEnabled)
      _Choices('Break After',
          ['30 min','1 hour','1.5 hrs','2 hours','3 hours'],
          ['30','60','90','120','180'],
          p.bingeGuardThresholdMinutes.toString(),
          (v) => onChanged((x) => x.copyWith(bingeGuardThresholdMinutes: int.parse(v)))),
    _Divider(),
    _Section('Sleep Fade 💤'),
    _Toggle('Fade Audio Before Sleep Timer', p.sleepFadeEnabled,
        (v) => onChanged((x) => x.copyWith(sleepFadeEnabled: v))),
    if (p.sleepFadeEnabled)
      _Choices('Fade Duration',
          ['15 sec','30 sec','60 sec'],
          ['15','30','60'],
          p.sleepFadeDurationSeconds.toString(),
          (v) => onChanged((x) => x.copyWith(sleepFadeDurationSeconds: int.parse(v)))),
    _Divider(),
    _Section('Skip Intro'),
    _Toggle('Show Skip Intro Button', p.showSkipIntroButton,
        (v) => onChanged((x) => x.copyWith(showSkipIntroButton: v))),
    _Toggle('Auto-Skip Intro', p.autoSkipIntroEnabled,
        (v) => onChanged((x) => x.copyWith(autoSkipIntroEnabled: v))),
    _Divider(),
    _Section('Debug Info'),
    _Toggle('Show Network Speed', p.showNetworkSpeed,
        (v) => onChanged((x) => x.copyWith(showNetworkSpeed: v))),
    _Toggle('Show Decoder Info', p.showDecoderInfo,
        (v) => onChanged((x) => x.copyWith(showDecoderInfo: v))),
    _Toggle('Vibrate on Gesture', p.vibrateOnGesture,
        (v) => onChanged((x) => x.copyWith(vibrateOnGesture: v))),
  ]);
}

// ── PLAYBACK TAB ──────────────────────────────────────────────────────────────
class _PlaybackTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _PlaybackTab({required this.p, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('Speed'),
    _Toggle('Remember Playback Speed', p.rememberSpeed,
        (v) => onChanged((x) => x.copyWith(rememberSpeed: v))),
    _Divider(),
    _Section('Resume'),
    _Toggle('Remember Position', p.rememberPosition,
        (v) => onChanged((x) => x.copyWith(rememberPosition: v))),
    _Choices('Seek Back on Resume',
        ['Off','3 sec','5 sec','10 sec'],
        ['0','3','5','10'],
        p.seekBackOnResumeSeconds.toString(),
        (v) => onChanged((x) => x.copyWith(seekBackOnResumeSeconds: int.parse(v)))),
    _Divider(),
    _Section('Episodes'),
    _Toggle('Auto-Play Next Episode', p.autoPlayNext,
        (v) => onChanged((x) => x.copyWith(autoPlayNext: v))),
    if (p.autoPlayNext) _Choices('Countdown Timer',
        ['5 sec','10 sec','15 sec'],
        ['5','10','15'],
        p.nextEpisodeCountdown.toString(),
        (v) => onChanged((x) => x.copyWith(nextEpisodeCountdown: int.parse(v)))),
    _Divider(),
    _Section('System'),
    _Toggle('Hardware Decoder', p.hwDecoderEnabled,
        (v) => onChanged((x) => x.copyWith(hwDecoderEnabled: v))),
    _Toggle('Background Audio', p.backgroundPlayEnabled,
        (v) => onChanged((x) => x.copyWith(backgroundPlayEnabled: v))),
    _Toggle('Long-Press Play = Restart from Beginning', p.longPressPlayRestart,
        (v) => onChanged((x) => x.copyWith(longPressPlayRestart: v))),
  ]);
}

// ── TRACK MEMORY TAB ──────────────────────────────────────────────────────────
class _TrackMemoryTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _TrackMemoryTab({required this.p, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('Language Memory'),
    _Toggle('Remember Audio Language', p.rememberAudioTrack,
        (v) => onChanged((x) => x.copyWith(rememberAudioTrack: v))),
    _Toggle('Remember Subtitle Language', p.rememberSubtitleTrack,
        (v) => onChanged((x) => x.copyWith(rememberSubtitleTrack: v))),
    _Toggle('Auto-Select by Device Language', p.autoSelectAudioByLocale,
        (v) => onChanged((x) => x.copyWith(autoSelectAudioByLocale: v))),
    _Divider(),
    _Section('Badges'),
    _Toggle('Show Active Track Badge', p.showActiveTrackBadge,
        (v) => onChanged((x) => x.copyWith(showActiveTrackBadge: v))),
    _Toggle('Show Track Count Badge', p.showTrackCountBadge,
        (v) => onChanged((x) => x.copyWith(showTrackCountBadge: v))),
    _Divider(),
    const Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        'Track memory saves your last selected audio and subtitle language so RaddFlix can auto-select it on the next video.',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
    ),
  ]);
}

// ── APPEARANCE TAB ────────────────────────────────────────────────────────────
class _AppearanceTab extends StatelessWidget {
  final PlayerPrefs p;
  final void Function(PlayerPrefs Function(PlayerPrefs) fn) onChanged;
  const _AppearanceTab({required this.p, required this.onChanged});

  @override
  Widget build(BuildContext context) => _SettingsList(children: [
    _Section('Theme'),
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Text('Accent Color', style: TextStyle(color: Colors.white70, fontSize: 13)),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE8002D),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24)),
          ),
        ),
        const SizedBox(width: 8),
        const Text('#E8002D', style: TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
    ),
    _SliderRow('UI Font Scale', p.uiFontSize, 0.8, 1.2,
        (v) => onChanged((x) => x.copyWith(uiFontSize: v)),
        displayFn: (v) => '${v.toStringAsFixed(1)}×', divisions: 8),
    _Divider(),
    _Section('Info Overlays'),
    _Toggle('Show Network Speed', p.showNetworkSpeed,
        (v) => onChanged((x) => x.copyWith(showNetworkSpeed: v))),
    _Toggle('Show Decoder Badge (HW/SW)', p.showDecoderInfo,
        (v) => onChanged((x) => x.copyWith(showDecoderInfo: v))),
    _Toggle('Show Playback Info', p.showPlaybackInfo,
        (v) => onChanged((x) => x.copyWith(showPlaybackInfo: v))),
    _Toggle('Show Episode Info', p.showEpisodeInfo,
        (v) => onChanged((x) => x.copyWith(showEpisodeInfo: v))),
    _Divider(),
    _Section('Haptics'),
    _Toggle('Vibrate on Gesture', p.vibrateOnGesture,
        (v) => onChanged((x) => x.copyWith(vibrateOnGesture: v))),
    _Toggle('Vibrate on Bookmark Save', p.bookmarkVibrate,
        (v) => onChanged((x) => x.copyWith(bookmarkVibrate: v))),
  ]);
}

// ── SHARED WIDGETS ────────────────────────────────────────────────────────────

class _SettingsList extends StatelessWidget {
  final List<Widget> children;
  const _SettingsList({required this.children});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 40),
    children: children,
  );
}

class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(title,
      style: const TextStyle(
        color: Color(0xFFE8002D), fontSize: 11,
        fontWeight: FontWeight.w700, letterSpacing: 0.8)),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: Colors.white12, height: 1, indent: 16, endIndent: 16);
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Toggle(this.label, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => SwitchListTile(
    title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
    value: value,
    activeColor: const Color(0xFFE8002D),
    onChanged: onChanged,
    dense: true,
  );
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final ValueChanged<double> onChanged;
  final String unit;
  final int? divisions;
  final String Function(double)? displayFn;
  const _SliderRow(this.label, this.value, this.min, this.max, this.onChanged,
      {this.unit = '', this.divisions, this.displayFn});
  @override
  Widget build(BuildContext context) {
    final disp = displayFn != null ? displayFn!(value) : '${value.toStringAsFixed(1)}$unit';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(children: [
        SizedBox(width: 140,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13))),
        Expanded(child: Slider(
          value: value.clamp(min, max),
          min: min, max: max,
          activeColor: const Color(0xFFE8002D),
          inactiveColor: Colors.white12,
          divisions: divisions,
          onChanged: onChanged,
        )),
        SizedBox(width: 52,
            child: Text(disp,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.right)),
      ]),
    );
  }
}

class _Choices extends StatelessWidget {
  final String label;
  final List<String> labels;
  final List<String> values;
  final String selected;
  final ValueChanged<String> onSelected;
  const _Choices(this.label, this.labels, this.values, this.selected, this.onSelected);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6,
        children: List.generate(labels.length, (i) => ChoiceChip(
          label: Text(labels[i]),
          selected: selected == values[i],
          selectedColor: const Color(0xFFE8002D),
          labelStyle: TextStyle(
            color: selected == values[i] ? Colors.white : Colors.white54,
            fontSize: 12),
          backgroundColor: Colors.white10,
          onSelected: (_) => onSelected(values[i]),
        ))),
    ]),
  );
}

class _WarningRow extends StatelessWidget {
  final String text;
  final Color color;
  const _WarningRow(this.text, this.color);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    child: Text(text, style: TextStyle(color: color, fontSize: 11)),
  );
}
