# RaddFlix Player — Supreme Customizable Player Specification
> **FINAL — For implementation agent. Read every section before writing code.**
> **Research basis:** MX Player, VLC, KMPlayer, Nova, BSPlayer, nPlayer, Just Player, mpv, Potplayer, Infuse
> **Last updated:** 2026-05-28 Session 5 (MX Player redesign + bug fixes applied)
> **Platform:** Android only. No iOS code needed. All MPV filters unrestricted.

---

## 0. What Already Exists — DO NOT Rebuild

```
✅ Swipe left = brightness, right = volume, horizontal = seek
✅ Double-tap left/right = ±15s seek with flash animation
✅ Long-press = 2× speed badge (hardcoded, make configurable)
✅ Pinch to zoom (1.0×–5.0×) + zoom level indicator
✅ Zoom reset button — already wired (onResetZoom callback)
✅ Fit/ratio cycling (contain / cover / fill / 16:9 / 4:3)
✅ Lock button — hides controls, tap right edge to unlock
✅ Speed picker panel (slides from right)
✅ Audio track panel — language names already work via ISO 639 map
✅ Subtitle track panel — language names already work
✅ Sleep timer panel + badge
✅ Skip intro button — HARDCODED at 85s → REPLACE with SmartIntroStore (§3.3)
✅ Next episode countdown overlay
✅ PiP via MethodChannel
✅ Chromecast via MethodChannel
✅ Buffering indicator (white — CHANGE TO ACCENT COLOR, see §3.19)
✅ Link loading overlay (JazzDrive URL resolution)
✅ Seek scrub label + thumbnail preview (local files)
✅ Brightness/volume gesture pill
✅ Resume position saved every 10s to SQLite
✅ flutter_animate imported and used
✅ shimmer package in pubspec (not yet used in player)
✅ share_plus in pubspec (use for timestamp share)
  ✅ MX Player-style controls overlay — right-side vertical icon strip (_MxSideBtn ×9: Audio/Sub/Fit/Speed/Night/Loop/Sleep/Bookmark/More), large red circle (76px) play/pause with glow, circular ±15s seek buttons (_MxSeekBtn) with second labels, top delay/zoom badges (_MxBadge)
  ✅ Error popup false-positive fix — error listener returns early if _playing && _position.inSeconds > 3 (no popup during active playback)
  ✅ Retry timer extended 5s → 8s with !_playing guard — prevents false retry on slow-starting but valid streams
  ✅ Play Now null fileId — shows SnackBar "Video not available yet" instead of silent return
  ```

  > **Last updated:** 2026-05-28 — Session 5 added MX Player redesign + 3 bug fixes

  Build ON TOP. Never delete working code.

---

## 1. Architecture — New Files

```
lib/
├── screens/
│   ├── player_screen.dart                  ← EXISTING — expand
│   └── player_settings_screen.dart         ← NEW
├── core/player/
│   ├── player_prefs.dart                   ← NEW
│   ├── player_prefs_provider.dart          ← NEW (Riverpod StateNotifier)
│   ├── smart_intro_store.dart              ← NEW
│   ├── ambilight_controller.dart           ← NEW
│   ├── binge_guard_controller.dart         ← NEW
│   ├── scene_bookmark_store.dart           ← NEW
│   ├── ab_loop_controller.dart             ← NEW
│   └── equalizer_controller.dart          ← NEW
├── widgets/player/
│   ├── player_gesture_layer.dart           ← NEW
│   ├── player_controls_bar.dart            ← NEW
│   ├── player_button_editor.dart           ← NEW
│   ├── player_settings_screen.dart         ← NEW
│   ├── cinematic_overlay.dart              ← NEW
│   ├── subtitle_overlay.dart               ← NEW
│   ├── sync_panel.dart                     ← NEW (shared: audio + sub delay)
│   ├── eq_panel.dart                       ← NEW
│   ├── ab_loop_panel.dart                  ← NEW
│   ├── video_enhance_panel.dart            ← NEW
│   ├── ambilight_glow_border.dart          ← NEW
│   ├── transparent_player_layer.dart       ← NEW
│   ├── scene_bookmarks_panel.dart          ← NEW
│   ├── binge_guard_overlay.dart            ← NEW
│   ├── rotation_picker.dart               ← NEW
│   ├── track_badges.dart                   ← NEW (active track pills)
│   └── playback_info_overlay.dart          ← NEW (codec/resolution/fps)
```

---

## 2. PlayerPrefs Model (`player_prefs.dart`)

SharedPreferences prefix: `player_`

```dart
class PlayerPrefs {

  // ── GESTURES ──────────────────────────────────────────────────
  bool gestureEnabled;               // master toggle (default: true)
  bool swipeBrightnessEnabled;       // (default: true)
  bool swipeVolumeEnabled;           // (default: true)
  bool swipeSeekEnabled;             // (default: true)
  bool doubleTapSeekEnabled;         // (default: true)
  int  doubleTapSeekSeconds;         // 5/10/15/20/30 (default: 10)
  bool longPressSpeedEnabled;        // (default: true)
  double longPressSpeed;             // 1.5/2.0/2.5/3.0 (default: 2.0)
  bool pinchZoomEnabled;             // (default: true)
  double swipeSensitivity;           // 0.5–2.0 (default: 1.0)
  double seekSensitivity;            // 0.5–2.0 (default: 1.0)
  double gestureZoneWidth;           // 0.3–0.5 (default: 0.4)
  bool rageSkipEnabled;              // triple-tap center (default: true)
  int  rageSkipSeconds;              // 60/120/180/300 (default: 120)
  bool swipeDownToExitEnabled;       // swipe down from top = exit player (default: false)

  // ── CONTROLS BAR ──────────────────────────────────────────────
  List<String> topBarButtons;
  List<String> bottomBarButtons;
  double buttonSize;                 // 0.8–1.4 (default: 1.0)
  double controlBarOpacity;         // 0.3–1.0 (default: 0.85)
  int    autoHideSeconds;            // 2/3/5/10/0=never (default: 3)
  bool   showSeekBar;
  bool   showTimeElapsed;            // (default: true)
  bool   showTimeRemaining;          // (default: false)
  bool   tapTimeToToggleRemaining;   // tap time = swap elapsed/remaining (default: true)
  bool   showChapterMarkers;
  bool   showThumbnailPreview;       // local files only
  bool   showBufferBar;
  bool   compactTopBar;
  String seekBarThumbStyle;          // 'dot'/'line'/'circle' (default: 'circle')

  // ── SUBTITLES ─────────────────────────────────────────────────
  bool   subtitleAutoDetect;         // local files only
  String subtitleEncoding;           // 'auto'/'utf-8'/'latin1'/'windows-1252'
  double subtitleFontSize;           // 10–40 (default: 18)
  String subtitleFontFamily;         // (default: 'Sans-Serif')
  bool   subtitleBold;
  bool   subtitleItalic;
  Color  subtitleTextColor;          // (default: Colors.white)
  Color  subtitleOutlineColor;       // (default: Colors.black)
  double subtitleOutlineThickness;   // 0–4 (default: 2.0)
  Color  subtitleBackgroundColor;
  double subtitleBackgroundOpacity;  // 0–1 (default: 0.0)
  String subtitlePosition;           // 'bottom'/'top'/'center' (default: 'bottom')
  double subtitleVerticalOffset;     // (default: 0.1)
  int    subtitleTimingOffsetMs;     // -5000–+5000 (default: 0)
  bool   subtitleEnabled;

  // ── AUDIO ─────────────────────────────────────────────────────
  int    audioTimingOffsetMs;        // -5000–+5000 (default: 0)
  double volumeBoostMultiplier;      // 1.0–3.0 = 100%–300% (default: 1.0)
  bool   equalizerEnabled;
  String equalizerPreset;            // 'flat'/'rock'/'pop'/'bass'/'movie'/'voice'/'custom'
  List<double> equalizerBands;       // 10 bands -12dB to +12dB
  bool   audioNormalization;
  bool   stereoMono;                 // false=stereo, true=mono
  double audioBalance;               // -1.0–+1.0 (default: 0.0)
  bool   dialogueBoostEnabled;
  bool   deinterlaceEnabled;         // MPV deinterlace (default: false)

  // ── TRACK INTELLIGENCE ────────────────────────────────────────
  bool   rememberAudioTrack;         // (default: true)
  bool   rememberSubtitleTrack;      // (default: true)
  bool   autoSelectAudioByLocale;    // (default: true)
  bool   showActiveTrackBadge;       // (default: true)
  bool   showTrackCountBadge;        // (default: true)
  // Track memory keys (in SharedPrefs, not PlayerPrefs object):
  //   'player_last_audio_lang' → language code e.g. 'urd'
  //   'player_last_sub_lang'   → language code e.g. 'eng'

  // ── VIDEO ENHANCEMENT ─────────────────────────────────────────
  double brightness;                 // -0.5–+0.5 (default: 0.0)
  double contrast;                   // -0.5–+0.5 (default: 0.0)
  double saturation;                 // -0.5–+0.5 (default: 0.0)
  double hue;                        // -180–+180° (default: 0.0)
  bool   nightMode;
  double nightModeIntensity;         // 0.1–1.0 (default: 0.5)
  bool   sharpnessEnabled;
  double sharpness;                  // 0.0–1.0 (default: 0.3)

  // ── ROTATION ──────────────────────────────────────────────────
  String rotationMode;
  // Values: 'sensor_landscape' (default) | 'auto' | 'lock_left' |
  //         'lock_right' | 'lock_portrait' | 'lock_current'

  // ── PLAYBACK ──────────────────────────────────────────────────
  double playbackSpeed;
  bool   rememberSpeed;
  bool   rememberPosition;
  bool   autoPlayNext;
  int    nextEpisodeCountdown;       // 5/10/15 (default: 10)
  bool   hwDecoderEnabled;
  bool   backgroundPlayEnabled;
  bool   preventScreenOff;
  int    seekBackOnResumeSeconds;    // 0/3/5/10 (default: 5)
  bool   longPressPlayRestart;       // long-press play = restart (default: false)

  // ── SMART SKIP INTRO ──────────────────────────────────────────
  bool   autoSkipIntroEnabled;       // (default: false)
  bool   showSkipIntroButton;        // (default: true)

  // ── TRANSPARENT PLAYER ────────────────────────────────────────
  bool   transparentModeEnabled;
  double transparentModeOpacity;     // 0.2–1.0 (default: 0.5)
  bool   transparentModeFrosted;

  // ── AMBILIGHT ─────────────────────────────────────────────────
  bool   ambilightEnabled;
  double ambilightIntensity;         // 0.3–1.0 (default: 0.7)
  double ambilightBlurRadius;        // 20–80 (default: 40)
  int    ambilightSampleIntervalMs;  // 200/400/800 (default: 400)

  // ── BINGE GUARD ───────────────────────────────────────────────
  bool   bingeGuardEnabled;
  int    bingeGuardThresholdMinutes; // 60/90/120/180 (default: 120)

  // ── SLEEP FADE ────────────────────────────────────────────────
  bool   sleepFadeEnabled;           // (default: true)
  int    sleepFadeDurationSeconds;   // 15/30/60 (default: 30)

  // ── BOOKMARKS ─────────────────────────────────────────────────
  bool   bookmarkVibrate;            // (default: true)

  // ── CINEMATIC ─────────────────────────────────────────────────
  bool   cinematicModeOnLock;
  bool   gesturesInCinematic;
  String cinematicTapBehavior;       // 'pause_resume'/'show_controls'

  // ── UI ────────────────────────────────────────────────────────
  String accentColor;                // hex (default: '#E8002D')
  double uiFontSize;                 // 0.8–1.2 (default: 1.0)
  bool   showEpisodeInfo;
  bool   showNetworkSpeed;
  bool   showDecoderInfo;            // HW/SW badge
  bool   showPlaybackInfo;           // codec + resolution + fps overlay
  bool   vibrateOnGesture;
}
```

---

## 3. Feature Specifications

### 3.1 Gesture System

Zones (configurable width, default 40% / 20% / 40%):
```
┌───────────────────────────────────────────┐
│  LEFT (Brightness) │ CENTER │ RIGHT (Vol) │
└───────────────────────────────────────────┘
```

| Gesture | Action | Configurable |
|---|---|---|
| Swipe up/down left | Brightness | ✅ disable, sensitivity |
| Swipe up/down right | Volume | ✅ disable, sensitivity |
| Swipe horizontal | Seek | ✅ disable, sensitivity |
| Double-tap left | Seek back N sec | ✅ 5/10/15/20/30 |
| Double-tap right | Seek forward N sec | ✅ 5/10/15/20/30 |
| Double-tap center | Play/Pause | ✅ |
| Single tap center | Show/hide controls | always |
| Long-press | Speed boost (hold) | ✅ disable, speed |
| Pinch | Zoom | ✅ disable |
| **Triple-tap center** | **Rage Skip** | ✅ disable, seconds |
| Two-finger swipe down | Exit player | ✅ `swipeDownToExitEnabled` |
| Swipe left edge | Chapter prev | ✅ |
| Swipe right edge | Chapter next | ✅ |

**Visual feedback — see §3.19 for animation details.**

---

### 3.2 Cinematic Mode

Controls fully hidden. Gestures still active.

- Entry: lock button (if `cinematicModeOnLock`) OR dedicated button
- Exit: swipe up from bottom → minimal strip (seek + play + time) auto-hides after 3s
- `cinematicTapBehavior = 'pause_resume'`: tap = play/pause
- `cinematicTapBehavior = 'show_controls'`: tap = show controls 2s

---

### 3.3 Smart Skip Intro

**Show only for:** `series` `drama` `anime` `donghua` `cartoon` `show`
**Never show for:** `movie` `song` `clip` `short` `documentary` `music_video`
**Never show if:** duration < 10 minutes

`PlayerScreen` needs new `String contentType` parameter from catalog data.

```dart
// smart_intro_store.dart
// SharedPrefs key: 'player_intro_times' → JSON {series_id: seconds}
class SmartIntroStore {
  Future<int?> getIntroTime(String seriesId);
  Future<void> saveIntroTime(String seriesId, int seconds);
  Future<void> clearIntroTime(String seriesId);
}
```

Flow:
1. No saved time → no button. One-time tooltip: "Long-press seek bar to set intro end"
2. User taps Skip → save position for `series_id`, applies to ALL episodes of that series
3. Next episode → auto-show button at saved time, or auto-skip if `autoSkipIntroEnabled`
4. Long-press Skip button → "Clear saved time for this series"
5. Long-press seek bar → context menu: "Set intro end here"

---

### 3.4 A-B Loop

- Tap A-B → set A (button orange)
- Tap again → set B, loop starts (button red)
- Tap again → clear
- Seek bar: colored dots at A and B positions

---

### 3.5 Subtitle System

**Panel tabs:** Tracks | Style | Sync | Encoding

**Tracks tab:** list of tracks, active one highlighted (see §3.15)
**Style tab:** font size, family, bold/italic, text color, outline, background, position
**Sync tab:** see §3.14
**Encoding tab:** Auto / UTF-8 / Latin-1 / Windows-1252 picker

**Auto-detect (local files only):** scan folder for `.srt` `.ass` `.ssa` `.vtt` `.sub`
External file loaded → show as `"English (File)"` or just filename in track list.

**Long-press subtitle text → copy to clipboard** + snackbar "Copied".

---

### 3.6 Audio System

**Panel tabs:** Tracks | Sync | EQ

**Dialogue Boost (Voice Clarity):**
One-tap. Fixed MPV EQ: `310Hz:+2, 600Hz:+4, 1kHz:+5, 3kHz:+4, 6kHz:+2`, others 0.
Cannot run simultaneously with custom EQ.

**10-Band EQ:**
Bands: 60/170/310/600/1k/3k/6k/12k/14k/16kHz, ±12dB each.
Presets: Flat / Rock / Pop / Bass Boost / Movie / Voice / Custom.

**Audio normalization:** MPV `dynaudnorm`
**Stereo/Mono + Balance:** MPV `pan`
**Deinterlace:** MPV `deinterlace=yes` — for old TV recordings

---

### 3.7 Video Enhancement

Build one combined `vf=` string:

```dart
String buildVfString(PlayerPrefs p) {
  final parts = <String>[];
  if (p.brightness!=0 || p.contrast!=0 || p.saturation!=0 || p.hue!=0)
    parts.add('eq=brightness=${p.brightness}:contrast=${1+p.contrast}:'
              'saturation=${1+p.saturation}:hue=${p.hue/180.0}');
  if (p.nightMode) {
    final i = p.nightModeIntensity;
    parts.add('colorchannelmixer=rr=${0.9+i*0.05}:rg=${0.1*i}:rb=${0.05*i}:'
              'gr=${0.01*i}:gg=${0.8+i*0.05}:gb=${0.05*i}:br=0:bg=0:bb=${0.7+i*0.1}');
  }
  if (p.sharpnessEnabled) parts.add('unsharp=la=${p.sharpness*2}:ca=${p.sharpness}');
  return parts.join(',');
}
await player.setProperty('vf', buildVfString(prefs));
```

---

### 3.8 Transparent / Ghost Player ★

```dart
// Video at configurable opacity
Opacity(opacity: prefs.transparentModeOpacity, child: Video(...))

// Controls: BackdropFilter frosted glass
BackdropFilter(
  filter: ImageFilter.blur(sigmaX:10, sigmaY:10),
  child: Container(color: Colors.black.withOpacity(0.3), child: _ControlsBar()),
)
```

Mini opacity slider bottom-left (20%–100%) when active.
Activate: ghost icon in top bar or quick settings.

---

### 3.9 Ambilight Glow Mode ★

Sample video frame edge pixels every N ms → colored box-shadow glow around video.
Uses `player.screenshot()` → decode → sample 10px strips on each edge → average color.

```dart
// ambilight_controller.dart: Timer → screenshot → sample → notify
// ambilight_glow_border.dart: AnimatedContainer with 4 BoxShadows (top/bottom/left/right)
// AnimatedContainer duration: 300ms (smooth color transition)
```

Settings: intensity (0.3–1.0), blur (20–80px), sample rate (200/400/800ms).

---

### 3.10 Binge Guard ★

Tracks active playback time (paused time excluded).
After threshold: break overlay with session stats.
"Take break" → pause + exit. "Keep watching" → dismiss, reset timer.

---

### 3.11 Sleep Fade ★

N seconds before sleep timer stops: smoothly fade MPV volume to 0, then pause + restore volume.
Show `"Sleeping in 30s..."` badge. Fade: 15s / 30s / 60s options.

---

### 3.12 Scene Bookmarks ★

Long-press seek bar → emoji picker (❤️ 🔥 😂 😮 💔 📌 ⭐ 🎯) → saved to SQLite.
Colored dots on seek bar. Bookmark panel: list, tap → seek, long-press → delete.

```dart
// Table: scene_bookmarks (id, content_id, episode_id, position_ms, emoji, created_at)
```

---

### 3.13 Rage Skip ★

Triple-tap center (600ms window) → skip forward N minutes.
Red flash + `"RAGE SKIP ⚡ +2:00"` badge with spring animation. Haptic: heavy.
Options: 1/2/3/5 min.

---

### 3.14 Audio & Subtitle Sync Panel

Access: Audio button → Sync tab | Subtitle button → Sync tab | Quick Settings.

```
┌─── Audio Sync ──────────────────────────────────────────┐
│                                                          │
│           Audio is delayed by  −200 ms                  │
│                                                          │
│  [−500] [−100] [−50]  [ Reset ↺ ]  [+50] [+100] [+500] │
│                                                          │
│  ◄─────────────────●───────────────────► (slider)        │
│ −5000ms                              +5000ms             │
│                                                          │
│  💡 If speech comes BEFORE lip movement → tap [+]        │
│     If speech comes AFTER  lip movement → tap [−]        │
│                                          [Done]          │
└──────────────────────────────────────────────────────────┘
```

Same layout for Subtitle Sync (sub-delay).

**Live header badges** (show in top bar when delay ≠ 0):
```dart
if (audioDelayMs != 0)
  _SyncBadge('Audio ${audioDelayMs>0?'+':''}${audioDelayMs}ms', onTap: () => _setAudioDelay(0))
if (subDelayMs != 0)
  _SyncBadge('Sub ${subDelayMs>0?'+':''}${subDelayMs}ms', onTap: () => _setSubDelay(0))
```
Tapping badge = instant reset to 0.

MPV:
```dart
await player.setProperty('audio-delay', '${ms / 1000.0}');
await player.setProperty('sub-delay',   '${ms / 1000.0}');
```

---

### 3.15 Track Intelligence

**Already working in code — keep as-is:**
- `_buildAudioLabels()` reads MPV ISO 639 metadata → shows Urdu/Hindi/English etc.
- `_buildSubLabels()` same for subtitles

**Must add:**

**1. Active track highlighted in picker:**
```dart
// _TracksPanel: add int activeIndex parameter
ListTile(
  title: Text(tracks[i], style: TextStyle(
    color: i==activeIndex ? AppColors.primary : Colors.white,
    fontWeight: i==activeIndex ? FontWeight.bold : FontWeight.normal)),
  trailing: i==activeIndex
    ? Icon(Icons.check_rounded, color: AppColors.primary, size: 18).animate().scale(begin: Offset(0,0), end: Offset(1,1), duration: 150.ms)
    : null,
  onTap: () => onSelect(i),
)
```

**2. Active track pills in top bar:**
```
← Title   [🎵 Urdu]  [CC English]   ⚙ ···
```
Tap `🎵 Urdu` → opens audio panel. Tap `CC English` → opens subtitle panel.
Show `CC Off` when subtitles disabled. Only show if `showActiveTrackBadge = true`.

**3. Track count badge:** `3A · 2S` — only when multiple tracks exist.

**4. Track memory:** Save last selected language code on track change. Auto-select on next open.

**5. Auto-select by locale:** On first play, match device `Locale.languageCode` → prefer matching audio language.

---

### 3.16 Small Essential Features

**A. Seek-Back on Resume:**
```dart
} else if (state == AppLifecycleState.resumed) {
  if (!_userPaused && prefs.seekBackOnResumeSeconds > 0 && _position.inSeconds > 5)
    _player.seek(_position - Duration(seconds: prefs.seekBackOnResumeSeconds));
  if (!_userPaused) WakelockPlus.enable();
}
```
Options: Off / 3s / 5s / 10s. Default: 5s.

**B. Tap Time = Toggle Elapsed / Remaining:**
```dart
bool _showRemaining = false;
// In time label onTap:
setState(() => _showRemaining = !_showRemaining);
// Display: _showRemaining ? '-${_fmtDur(_duration - _position)}' : _fmtDur(_position)
```

**C. Long-Press Time = Jump to Timestamp:**
Long-press the time display → bottom sheet with number-pad input.
User types `4520` → parsed as `45:20` → seek.
Accept formats: `SS`, `MMSS`, `HHMMSS`.

**D. Long-Press Play Button = Restart:**
Only if `longPressPlayRestart = true`. Long-press center play/pause → seek to 0 + brief toast.

**E. Android Media Notification + Audio Focus:**
```dart
// audio_session package:
final session = await AudioSession.instance;
await session.configure(AudioSessionConfiguration.video());
// Pause on phone call, resume after, pause on headphone unplug
session.interruptionEventStream.listen((event) {
  if (event.begin) _player.pause();
  else if (event.type == AudioInterruptionType.pause) _player.play();
});
session.becomingNoisyEventStream.listen((_) => _player.pause()); // unplug
```
media_kit handles Android MediaSession (lock screen controls) automatically via `PlayerConfiguration`.

**F. Headphone Button Support:**
Single press = play/pause. Double press = next episode. Triple press = seek back 10s.
Handled via `audio_session` + platform channel `onAudioFocusChange`.

**G. Volume Boost Indicator Badge:**
When `volumeBoostMultiplier > 1.0`, show persistent small badge in top-right:
- 100%–150%: white `🔊 150%`
- 150%–200%: orange `🔊 200%`
- 200%–300%: red `🔊 300%`
Tap badge → opens volume boost slider in quick settings.

**H. Long-Press Subtitle = Copy:**
```dart
GestureDetector(
  onLongPress: () {
    Clipboard.setData(ClipboardData(text: _currentSubtitleText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied'), duration: Duration(seconds: 2)));
  },
  child: _SubtitleWidget(),
)
```

**I. Share Timestamp:**
Long-press the time label → share sheet:
`"Watching [Title] at 45:20 on RaddFlix"` via `share_plus`.

**J. Playback Info Overlay:**
Toggle via top bar or `showPlaybackInfo` pref.
Shows: Decoder (HW/SW), Codec, Resolution, FPS, Bitrate, Buffer.
```dart
await player.getProperty('video-codec');      // e.g. "h264"
await player.getProperty('width');            // e.g. "1920"
await player.getProperty('height');           // e.g. "1080"
await player.getProperty('fps');              // e.g. "29.97"
await player.getProperty('video-bitrate');    // bits/s
await player.getProperty('demuxer-cache-duration'); // buffered seconds
```

---

### 3.17 Screen Rotation Control ★ Full MX Player Parity

**Rotation Modes:**

| Mode | Icon | SystemChrome call | Description |
|---|---|---|---|
| `sensor_landscape` | `Icons.screen_rotation_rounded` | `[landscapeLeft, landscapeRight]` | **Default.** Auto between left/right only, never portrait |
| `auto` | `Icons.screen_rotation_outlined` | `[all four]` | Full sensor — phone can rotate to portrait too |
| `lock_left` | `Icons.stay_current_landscape_rounded` | `[landscapeLeft]` | Force landscape left |
| `lock_right` | `Icons.screen_rotation_rounded` (rotated 180°) | `[landscapeRight]` | Force landscape right |
| `lock_portrait` | `Icons.stay_current_portrait_rounded` | `[portraitUp]` | Force portrait |
| `lock_current` | `Icons.screen_lock_rotation_rounded` | current orientation only | Lock to whatever it is right now |

**Rotate button in top bar:**
Cycles through: `sensor_landscape → lock_left → lock_right → lock_portrait → sensor_landscape`
Each press = `HapticFeedback.selectionClick()`

Icon changes to reflect current mode. Small mode label tooltip on icon (e.g. "Landscape Lock").

**Portrait video auto-detection:**
When video `height > width` (e.g., phone recording in portrait):
- Detect once when media loads
- If `rotationMode == 'sensor_landscape'`: show a one-time toast: "Portrait video — tap 🔄 to switch"
- Rotating button in this state switches to `lock_portrait`

**Implementation:**
```dart
void _applyRotation(String mode) {
  switch (mode) {
    case 'sensor_landscape':
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      break;
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
      final current = MediaQuery.of(context).orientation;
      SystemChrome.setPreferredOrientations(current == Orientation.landscape
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
        : [DeviceOrientation.portraitUp]);
      break;
  }
  setState(() => _rotationMode = mode);
  prefs.save(prefs.copyWith(rotationMode: mode));
}

// Always restore to system default on player dispose:
@override
void dispose() {
  SystemChrome.setPreferredOrientations(DeviceOrientation.values); // full auto on exit
  super.dispose();
}
```

**Rotation badge in top bar** (next to rotate icon):
`"🔄 Landscape"` / `"🔒 Left"` / `"🔒 Right"` / `"🔒 Portrait"` / `"🔄 Auto"`

---

### 3.18 Volume Boost to 300% — REAL Implementation

**This is real audio amplification, not fake/visual only.**
MPV's internal `volume` property accepts 0–1000 (100 = normal).
Setting it to 300 = 3× software amplification.

```
MX Player max: 200%
VLC max:       200%
RaddFlix max:  300%  ← we go further
```

**Implementation:**
```dart
void _applyVolumeBoost(double multiplier) {
  // Step 1: Set system volume to maximum
  VolumeController().setVolume(1.0);
  // Step 2: MPV internal amplification (100 = normal, 300 = 3×)
  player.setProperty('volume', '${(multiplier * 100).toInt()}');
}
// multiplier 1.0 = 100% (no boost), 2.0 = 200%, 3.0 = 300%
```

**UI:**
- Slider range: 100% → 300%
- Stops: 100% / 125% / 150% / 175% / 200% / 250% / 300%
- Below 200%: `🔊` white icon
- 200%–250%: `🔊` orange icon + small warning `"⚠ High volume"`
- 250%–300%: `🔊` red icon + warning `"⚠ May distort audio at 300%"`
- Badge in top bar persists when boost > 100% (tap to reset to 100%)

**Swipe volume gesture integration:**
- Swipe volume gesture controls system volume (0–100%)
- When system volume is already at 100% and user swipes up further → enters boost territory
- Boost level shown in different color (orange instead of white) in the pill

---

### 3.19 Animations & Visual Polish

Every animation uses `flutter_animate` (already imported). Use `AppCurves.standard` for consistency.

**Buffering Indicator — CHANGE FROM CURRENT:**
```dart
// CURRENT (bad): white70 color, no personality
// NEW:
Center(
  child: Stack(alignment: Alignment.center, children: [
    // Outer pulse ring
    Container(width: 60, height: 60,
      decoration: BoxDecoration(shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2)))
    .animate(onPlay: (c) => c.repeat())
    .scale(begin: Offset(1,1), end: Offset(1.4,1.4), duration: 900.ms)
    .fadeOut(duration: 900.ms),
    // Inner spinner
    SizedBox(width: 38, height: 38,
      child: CircularProgressIndicator(
        strokeWidth: 2.5, strokeCap: StrokeCap.round,
        valueColor: AlwaysStoppedAnimation(AppColors.primary))),
  ]),
)
```

**Link Loading (JazzDrive URL resolution):**
```dart
// Keep existing overlay but improve:
Column(children: [
  // Shimmer placeholder for video area
  Shimmer.fromColors(
    baseColor: Colors.grey[900]!, highlightColor: Colors.grey[700]!,
    child: Container(color: Colors.white)),
  // Loading text with dots animation
  Text('Loading...').animate(onPlay: (c) => c.repeat())
    .fadeIn(duration: 400.ms).then().fadeOut(duration: 400.ms),
])
```

**Controls Show/Hide:**
```dart
// Show
.animate().fadeIn(duration: 180.ms).slideY(begin: 0.02, end: 0, duration: 180.ms)
// Hide (wrap in AnimatedOpacity or use animate key)
.animate().fadeOut(duration: 180.ms)
```

**Gesture Pills (brightness/volume/seek/zoom):**
```dart
.animate()
  .scale(begin: Offset(0.85, 0.85), end: Offset(1,1),
         duration: 180.ms, curve: Curves.elasticOut)
  .fadeIn(duration: 100.ms)
```

**Seek Flash (double-tap ±Ns):**
Existing pattern is good. Keep `slideY + fadeIn`. Add slight scale:
```dart
.animate().fadeIn(300.ms).slideY(begin: 0.3, end: 0, duration: 300.ms)
```

**Rage Skip Badge:**
```dart
Container(child: Text('RAGE SKIP ⚡ +2:00'))
  .animate()
  .scale(begin: Offset(0.5, 0.5), end: Offset(1.1, 1.1), duration: 250.ms, curve: Curves.elasticOut)
  .then().scale(end: Offset(1, 1), duration: 100.ms)
  .then(delay: 600.ms).fadeOut(duration: 300.ms)
// Red flash behind it:
Container(color: Colors.red.withOpacity(0.25))
  .animate().fadeIn(duration: 50.ms).then(delay: 150.ms).fadeOut(duration: 200.ms)
```

**Track Selection Checkmark:**
```dart
Icon(Icons.check_rounded).animate().scale(
  begin: Offset(0,0), end: Offset(1,1),
  duration: 150.ms, curve: Curves.elasticOut)
```

**Skip Intro Button:**
Existing slide-up is good. Add subtle pulse border to draw attention:
```dart
.animate(onPlay: (c) => c.repeat(reverse: true))
  .custom(duration: 1200.ms,
    builder: (ctx, value, child) => Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3 + value * 0.5), width: 1.5),
        borderRadius: BorderRadius.circular(8)),
      child: child))
```

**Scene Bookmark Dot (appears on seek bar):**
```dart
.animate().scale(begin: Offset(0,0), end: Offset(1,1),
  duration: 350.ms, curve: Curves.elasticOut)
```

**Ambilight Colors:** `AnimatedContainer(duration: 300.ms)` — already smooth.

**Sync Badge (audio/sub delay in header):**
```dart
// Appears: slide down from top
.animate().fadeIn(200.ms).slideY(begin: -0.5, end: 0, duration: 200.ms)
// When reset (disappears): slide up + fade
.animate().fadeOut(200.ms).slideY(begin: 0, end: -0.5, duration: 200.ms)
```

**Volume Boost Badge:** Same slide-down animation as sync badge.

**Panels (speed picker, track panel):** Keep existing `.slideX(begin:1, end:0)` — works well.

**Seek Bar Thumb:** On drag start → scale thumb from 1.0× to 1.4× with spring.

---

### 3.20 Loading & Error States

**Initial load:**
1. Black screen + centered shimmer placeholder (not solid black)
2. Accent-color spinner after 500ms if still buffering
3. After 8 seconds → show `"Connecting..."` text

**Buffering during playback:**
- Small accent-color spinner top-right (not center-blocking)
- Center spinner only for full stalls (buffering > 2 seconds)

**Error / Failed stream:**
```dart
// Listen to player.stream.error
_player.stream.error.listen((error) {
  if (!mounted) return;
  setState(() => _streamError = error);
});

// Show error overlay:
if (_streamError != null)
  _StreamErrorOverlay(
    message: 'Could not load video',
    onRetry: () { setState(() => _streamError = null); _openMedia(widget.fileId); },
    onBack: () => Navigator.pop(context),
  )
```

**Slow connection warning:**
If buffering for > 8 seconds: toast `"Slow connection — video may stutter"`.

**Headphone unplug visual:**
When `audio_session` fires `becomingNoisy` → brief `"🎧 Headphones disconnected"` toast + pause.

---

## 4. PlayerSettingsScreen

```
PlayerSettingsScreen (full page, scroll)
├── Gestures
│   ├── Master toggle, per-gesture toggles + sensitivities
│   ├── Double-tap seconds, long-press speed
│   ├── Zone width slider
│   ├── Rage Skip (toggle + seconds)
│   └── Swipe down to exit
├── Controls
│   ├── Button size slider
│   ├── Control bar opacity slider
│   ├── Auto-hide timer
│   ├── Show/hide each button (checkboxes)
│   └── Seek bar: thumb style, buffer bar, time format
├── Rotation
│   ├── Default rotation mode picker (6 options with icons)
│   └── Portrait video: show tip toggle
├── Subtitles
│   ├── Style (font/color/outline/bg/position)
│   ├── Encoding override
│   └── Auto-detect toggle
├── Audio
│   ├── Equalizer + Dialogue Boost
│   ├── Volume boost slider (100%–300%)
│   ├── Normalization, Stereo/Mono, Balance
│   └── Deinterlace toggle
├── Video
│   ├── Brightness/Contrast/Saturation/Hue sliders
│   ├── Night Mode (toggle + intensity)
│   └── Sharpness
├── Track Settings
│   ├── Remember audio language
│   ├── Remember subtitle language
│   ├── Auto-select by device language
│   ├── Show active track badge
│   └── Show track count badge
├── New Features
│   ├── Ambilight (toggle + intensity + blur + speed)
│   ├── Transparent Player (toggle + opacity slider)
│   ├── Binge Guard (toggle + threshold)
│   ├── Sleep Fade (toggle + duration)
│   └── Rage Skip (same as Gestures section, link)
├── Playback
│   ├── Speed + remember speed
│   ├── Resume position
│   ├── Auto-play next + countdown
│   ├── Seek-back on resume (Off/3s/5s/10s)
│   ├── Long-press play = restart toggle
│   ├── Background audio
│   └── Hardware decoder
└── Appearance
    ├── Accent color picker (flutter_colorpicker)
    ├── UI font scale slider
    └── Info badges (network speed, decoder, volume boost, playback info)
```

---

## 5. Quick Settings Panel (In-Player)

```
┌─── Player Settings ────────────────────────────────────┐
│  Gestures      [══════● On]                            │
│  Subtitles     [════●  On]     Style →                 │
│  Sub Size      [───●───] 18px                          │
│  Sub Sync      −200ms  [Reset ↺]    [Full Sync →]      │
│  Audio Sync    +0ms    [Reset ↺]    [Full Sync →]      │
│  Speed         [ ×0.75 | ×1.0● | ×1.25 | ×1.5 | ×2 ] │
│  Dialogue Boost[●      Off]                            │
│  Night Mode    [●      Off]                            │
│  Volume Boost  [────●──────────────────] 150%  🔊      │
│  Ambilight     [●      Off]                            │
│  Transparent   [●      Off]    Opacity →               │
│  Rotation      [🔄 Landscape]  Change →                │
│  Auto-Hide     [3s●] 5s  10s                           │
│  Cinematic     [●      Off]                            │
│  Binge Guard   [═══════● On]                           │
│                                                        │
│  [ Full Settings → ]                [Done]             │
└────────────────────────────────────────────────────────┘
```

---

## 6. Supported Formats

| Type | Formats |
|---|---|
| Video | MP4, MKV, AVI, MOV, FLV, WMV, WEBM, TS, M2TS |
| Audio | MP3, AAC, AC3, DTS, FLAC, OGG, OPUS |
| Subtitles | SRT, ASS, SSA, VTT, SUB, SMI |
| Streaming | HLS (m3u8), HTTP MP4 direct link |

---

## 7. Player Modes

| Mode | Controls | Gestures | Rotation | Status bar |
|---|---|---|---|---|
| Normal | Auto-hide | ✅ | Per pref | Hidden |
| Cinematic | Hidden | ✅ | Per pref | Hidden |
| Locked | Hidden | ❌ | Locked | Hidden |
| Transparent | Frosted | ✅ | Per pref | Hidden |
| Background | — | — | System | System |
| PiP | Mini | ❌ | System | System |

---

## 8. Skip Intro Content Type Reference

| content_type | Show intro? |
|---|---|
| series / drama / anime / donghua / cartoon / show | ✅ |
| movie / song / clip / short / documentary / music_video | ❌ |
| Any type with duration < 10 min | ❌ |

---

## 9. Implementation Phases

### 3A — Foundation
1. `player_prefs.dart` + model
2. `player_prefs_provider.dart` (Riverpod StateNotifier)
3. Wire into `player_screen.dart` via `ref.watch(playerPrefsProvider)`
4. Replace hardcoded gesture values with prefs

### 3B — Controls & Settings Screen
1. `player_settings_screen.dart`
2. Quick settings bottom sheet
3. Button show/hide + auto-hide timer config

### 3C — Rotation + Smart Skip Intro + Track Intelligence
1. `_applyRotation()` + rotate button cycle + badge
2. `smart_intro_store.dart`
3. `content_type` param added to PlayerScreen
4. Smart intro logic
5. `_TracksPanel` active track highlight
6. Active track pills in top bar
7. Track count badge
8. Track memory + auto-select by locale

### 3D — Sync Panel
1. `sync_panel.dart`
2. ±50/100/500ms buttons + slider + Reset
3. Live delay badges in header

### 3E — Subtitle System
1. Style panel
2. Encoding picker
3. Auto-detect local files
4. Long-press subtitle = copy

### 3F — Cinematic Mode
1. `cinematic_overlay.dart`
2. Configurable lock behavior
3. Swipe-up minimal strip

### 3G — Audio & Video Enhancement
1. Volume boost 100%–300% + badge
2. Swipe-into-boost from 100% system volume
3. 10-band EQ + Dialogue Boost
4. Video filters (buildVfString)
5. Normalization + deinterlace

### 3H — Small Essential Features
1. Seek-back on resume (5-line fix in `didChangeAppLifecycleState`)
2. Tap time = toggle elapsed/remaining
3. Long-press time = jump to timestamp
4. Long-press play = restart
5. `audio_session` setup (audio focus + headphone unplug)
6. Android media notification
7. Orientation auto-restore on dispose
8. Share timestamp

### 3I — New Original Features
1. Sleep Fade
2. Rage Skip
3. Scene Bookmarks
4. Ambilight Mode
5. Transparent Player
6. Binge Guard

### 3J — Animations & Error States
1. Upgrade buffering indicator to accent color + pulse ring
2. Shimmer loading state
3. Error/retry overlay
4. Slow connection toast
5. All flutter_animate polish from §3.19

### 3K — Advanced
1. A-B Loop
2. Frame-by-frame (frame-step / frame-back-step)
3. Chapter markers on seek bar
4. Screenshot to gallery (gal package)
5. Playback info overlay

### Phase 4 (Future — not this agent)
- Drag-to-reorder button layout editor
- OpenSubtitles search (needs API key)
- Auto intro detection (audio fingerprinting)

---

## 10. MPV Command Reference

```dart
// EQ (combine all 10 bands in one af= string)
await player.setProperty('af',
  'equalizer=f=60:width_type=o:width=2:g=${b[0]},'
  'equalizer=f=170:width_type=o:width=2:g=${b[1]},'
  'equalizer=f=310:width_type=o:width=2:g=${b[2]},'
  'equalizer=f=600:width_type=o:width=2:g=${b[3]},'
  'equalizer=f=1000:width_type=o:width=2:g=${b[4]},'
  'equalizer=f=3000:width_type=o:width=2:g=${b[5]},'
  'equalizer=f=6000:width_type=o:width=2:g=${b[6]},'
  'equalizer=f=12000:width_type=o:width=2:g=${b[7]},'
  'equalizer=f=14000:width_type=o:width=2:g=${b[8]},'
  'equalizer=f=16000:width_type=o:width=2:g=${b[9]}');

// Volume boost (REAL amplification)
VolumeController().setVolume(1.0);                         // system to max
await player.setProperty('volume', '${(mult*100).toInt()}'); // MPV 100-300

// Video filters
await player.setProperty('vf', buildVfString(prefs));

// Audio delay
await player.setProperty('audio-delay', '${ms/1000.0}');

// Subtitle delay
await player.setProperty('sub-delay', '${ms/1000.0}');

// Deinterlace
await player.setProperty('deinterlace', enabled ? 'yes' : 'no');

// Hardware decoder
await player.setProperty('hwdec', enabled ? 'auto' : 'no');

// Frame step
await player.command(['frame-step']);
await player.command(['frame-back-step']);

// Screenshot
final Uint8List? frame = await player.screenshot();

// Playback info
final codec  = await player.getProperty('video-codec');
final width  = await player.getProperty('width');
final height = await player.getProperty('height');
final fps    = await player.getProperty('fps');
```

---

## 11. Packages

Add to `pubspec.yaml`:
```yaml
gal: ^2.3.0              # screenshot → gallery
flutter_colorpicker: ^1.1.0  # accent/subtitle color picker
audio_session: ^0.1.21   # audio focus + headphone unplug + media notification
```

Already in pubspec (DO NOT add again):
`media_kit`, `media_kit_video`, `media_kit_libs_android_video`, `shared_preferences`,
`screen_brightness`, `volume_controller`, `wakelock_plus`, `file_picker`,
`video_thumbnail`, `sqflite`, `path_provider`, `path`,
`flutter_animate`, `shimmer`, `share_plus`, `flutter_riverpod`

---

## 12. Files to Modify in Existing Code

| File | Change |
|---|---|
| `player_screen.dart` | Add `content_type` param; wire PlayerPrefs; fix lifecycle seek-back; rotation cycle button; upgrade buffering; error overlay |
| `player_screen.dart` `_TracksPanel` | Add `activeIndex` param; highlight selected track |
| `player_screen.dart` `_buildAudioLabels` | **Keep as-is** — already works |
| `player_screen.dart` `didChangeAppLifecycleState` | Add seek-back on resume |
| `player_screen.dart` skip intro | Replace hardcoded 85s with SmartIntroStore |
| `player_screen.dart` time label | Tap = toggle elapsed/remaining; long-press = jump to time |
| `player_screen.dart` `dispose()` | Restore `DeviceOrientation.values` on exit |
| `app.dart` | Add route `'/player-settings': PlayerSettingsScreen` |
| `pubspec.yaml` | Add `gal`, `flutter_colorpicker`, `audio_session` |

---

## 13. Icons Reference (use these exact icons — no substitutions)

| Feature | Icon |
|---|---|
| Rotation: sensor landscape | `Icons.screen_rotation_rounded` |
| Rotation: lock left | `Icons.stay_current_landscape_rounded` |
| Rotation: lock right | `Icons.stay_current_landscape_rounded` + `Transform.rotate(angle: pi)` |
| Rotation: lock portrait | `Icons.stay_current_portrait_rounded` |
| Rotation: full auto | `Icons.screen_rotation_outlined` |
| Rotation: lock current | `Icons.screen_lock_rotation_rounded` |
| Audio tracks | `Icons.audiotrack_rounded` (existing) |
| Subtitles | `Icons.subtitles_outlined` (existing) |
| Subtitle off | `Icons.subtitles_off_outlined` |
| Settings/tune | `Icons.tune_rounded` |
| Sleep timer | `Icons.bedtime_outlined` / `Icons.bedtime_rounded` (active) |
| PiP | `Icons.picture_in_picture_alt_rounded` |
| Cast | `Icons.cast_rounded` / `Icons.cast_connected_rounded` |
| Lock | `Icons.lock_outline_rounded` / `Icons.lock_open_rounded` |
| Cinematic | `Icons.crop_free_rounded` |
| Night mode | `Icons.nightlight_rounded` |
| EQ | `Icons.equalizer_rounded` |
| Zoom reset | `Icons.zoom_out_map_rounded` |
| Ambilight | `Icons.blur_on_rounded` |
| Transparent | `Icons.opacity` |
| Binge guard | `Icons.health_and_safety_outlined` |
| Rage Skip | `Icons.bolt_rounded` |
| Bookmark | `Icons.bookmark_border_rounded` / `Icons.bookmark_rounded` |
| Screenshot | `Icons.screenshot_monitor_rounded` |
| Share | `Icons.share_rounded` |
| Copy | `Icons.copy_rounded` |
| Reset/Refresh | `Icons.refresh_rounded` |
| Seek back 15s | `Icons.replay_rounded` (+ "15" label — existing) |
| Seek fwd 15s | `Icons.forward_rounded` (+ "15" label — existing) |
| Play/pause | `Icons.play_arrow_rounded` / `Icons.pause_rounded` (existing) |
| A-B loop | `Icons.loop_rounded` |
| Frame step | `Icons.skip_next_rounded` / `Icons.skip_previous_rounded` |
| Dialogue boost | `Icons.record_voice_over_rounded` |
| Volume boost | `Icons.volume_up_rounded` → `Icons.speaker_rounded` (when boosted) |
| Active track badge music | `Icons.music_note_rounded` |
| Active track badge CC | `Icons.closed_caption_rounded` / `Icons.closed_caption_disabled_rounded` |
| Info overlay | `Icons.info_outline_rounded` |
| Deinterlace | `Icons.view_stream_rounded` |
| Back (exit player) | `Icons.arrow_back_ios_new_rounded` (existing) |

---

## 14. Testing Checklist (Run ALL before pushing)

**Foundation:**
- [ ] PlayerPrefs loads on cold start, all values persist after player close/reopen
- [ ] Changing any pref takes effect immediately in the player

**Gestures:**
- [ ] All existing gestures still work (brightness, volume, seek, double-tap, long-press, zoom)
- [ ] Gesture sensitivity changes work immediately
- [ ] Rage Skip: triple-tap center → red flash + badge + correct skip distance
- [ ] Swipe down to exit (when enabled)

**Rotation:**
- [ ] Rotate button cycles: sensor_landscape → lock_left → lock_right → lock_portrait
- [ ] Each mode correctly sets SystemChrome orientation
- [ ] Exiting player → device rotation restores to system auto (all orientations)
- [ ] Portrait video detected → tip shown
- [ ] Rotation badge in top bar shows current mode

**Skip Intro:**
- [ ] Shows for drama/anime — does NOT show for movies/songs
- [ ] Does NOT show if duration < 10 min
- [ ] Tapping Skip saves time for series_id
- [ ] Next episode auto-shows skip button at saved time
- [ ] Long-press Skip → "Clear saved time" works

**Tracks:**
- [ ] Active audio track highlighted with checkmark in picker
- [ ] Active subtitle track highlighted
- [ ] `🎵 Urdu` badge visible in top bar when Urdu audio active
- [ ] `CC English` badge visible when subtitles active; `CC Off` when disabled
- [ ] Track count badge shows (e.g. `3A · 2S`)
- [ ] Track memory: select Urdu, close player, reopen → Urdu auto-selected

**Sync:**
- [ ] Audio sync ±50ms/±100ms/±500ms buttons adjust MPV audio-delay in real time
- [ ] Subtitle sync buttons adjust MPV sub-delay in real time
- [ ] Reset ↺ sets delay to 0ms immediately
- [ ] `Audio −200ms ↺` badge appears in header when audio delay ≠ 0
- [ ] `Sub +300ms ↺` badge appears when sub delay ≠ 0
- [ ] Tapping badge resets to 0

**Volume Boost:**
- [ ] Slider goes from 100% to 300%
- [ ] Audio is actually louder at 300% (test with headphones — real amplification)
- [ ] `🔊 150%` badge shows in top bar when boost > 100%
- [ ] Badge turns orange at 200%, red at 250%+
- [ ] Warning text appears above 200%

**Audio/Video:**
- [ ] All EQ presets apply correctly and sound different
- [ ] Dialogue Boost makes voice frequencies clearer
- [ ] Night mode applies warm tint
- [ ] Brightness/contrast/saturation/hue all work independently

**Small Features:**
- [ ] Tap time label → toggles elapsed/remaining
- [ ] Long-press time → jump-to-timestamp sheet works
- [ ] Leave app 5 seconds, return → player seeked back 5 seconds
- [ ] Headphone unplug → player pauses
- [ ] Media notification shows when playing (lock screen)
- [ ] Long-press subtitle line → "Copied" snackbar + clipboard has text

**Error States:**
- [ ] Broken stream URL → error overlay shows with Retry button
- [ ] Retry actually reattempts `_openMedia()`
- [ ] Buffering spinner is accent color (#E8002D), not white

**New Features:**
- [ ] Transparent: opacity slider changes video transparency in real time
- [ ] Ambilight: glow matches video scene colors, updates smoothly
- [ ] Sleep Fade: volume fades before timer ends (test with short timer)
- [ ] Scene Bookmark: long-press seek bar → emoji → dot on seek bar → panel shows it
- [ ] Binge Guard fires at configured time (test with 1 min for dev)
- [ ] Cinematic: controls hidden, gestures work, tap = pause/resume

**Performance:**
- [ ] Player opens in < 1 second on mid-range Android
- [ ] Seek does not cause full rebuild of widget tree (only _positionNotifier updates)
- [ ] Ambilight sample rate at 400ms — check CPU usage is < 5% overhead
- [ ] `flutter analyze` — zero errors, zero warnings

