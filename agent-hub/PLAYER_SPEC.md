# RaddFlix Player — Supreme Customizable Player Specification
> **Task for next agent:** Implement everything in this document into `player_screen.dart` and related files.
> **Research basis:** MX Player, VLC, nPlayer, Infuse, KMPlayer, BSPlayer, Kodi, PowerDVD, Nova, Just Player, mpv, Vimu, PlayerXtreme, Plex, Jellyfin, Potplayer
> **Last updated:** 2026-05-26 Session 6
> **Status:** SPEC ONLY — no code written yet for new features

---

## 0. What Already Exists (DO NOT rebuild)

Current `player_screen.dart` already has:
- ✅ Swipe left = brightness, swipe right = volume, horizontal swipe = seek
- ✅ Double-tap left/right = ±15s seek with flash animation
- ✅ Long-press = 2× speed badge
- ✅ Pinch to zoom + zoom level indicator
- ✅ Fit/ratio cycling (fit/fill/stretch/16:9/4:3)
- ✅ Lock button (hides controls, tap right edge to unlock)
- ✅ Speed picker panel (slides from right)
- ✅ Audio track selection panel
- ✅ Subtitle track selection panel (embedded)
- ✅ Sleep timer panel + badge
- ✅ Skip intro button (fixed at 85s — **needs to be replaced with smart version, see §3.3**)
- ✅ Next episode countdown overlay
- ✅ PiP via MethodChannel
- ✅ Chromecast via MethodChannel
- ✅ Buffering indicator
- ✅ Seek scrub label with position preview
- ✅ Drag indicator for brightness/volume

Build ON TOP of these. Do not remove them.

---

## 0.1 Platform

**Android only.** This app has no iOS users. Do not add any iOS-specific code, conditions, or comments. All MPV video and audio filters work without restriction on Android.

---

## 1. Architecture — New Files to Create

```
raddflix_flutter/lib/
├── screens/
│   ├── player_screen.dart                  ← existing, expand this
│   └── player_settings_screen.dart         ← NEW: full player customization UI
├── core/
│   ├── player/
│   │   ├── player_prefs.dart               ← NEW: all player preferences model + SharedPrefs persistence
│   │   ├── player_prefs_provider.dart      ← NEW: Riverpod StateNotifier for player prefs
│   │   ├── subtitle_service.dart           ← NEW: auto-detect + parse + style subtitles
│   │   ├── ab_loop_controller.dart         ← NEW: A-B loop logic
│   │   ├── equalizer_controller.dart       ← NEW: EQ state + media_kit EQ integration
│   │   ├── player_button_layout.dart       ← NEW: customizable button position model
│   │   ├── smart_intro_store.dart          ← NEW: save/load intro times per series
│   │   ├── ambilight_controller.dart       ← NEW: frame color sampling + glow state
│   │   ├── binge_guard_controller.dart     ← NEW: session watch time tracker
│   │   └── scene_bookmark_store.dart       ← NEW: save/load bookmarks to SQLite
│   └── services/
│       └── subtitle_search_service.dart    ← NEW: OpenSubtitles API integration (needs API key)
├── widgets/player/
│   ├── player_gesture_layer.dart           ← NEW: extracted, configurable gesture zones
│   ├── cinematic_overlay.dart              ← NEW: cinematic mode layer
│   ├── subtitle_overlay.dart               ← NEW: styled subtitle rendering
│   ├── seek_thumbnail.dart                 ← NEW: thumbnail preview on seek (local files only)
│   ├── eq_panel.dart                       ← NEW: 10-band equalizer widget
│   ├── ab_loop_panel.dart                  ← NEW: A-B loop control widget
│   ├── video_enhance_panel.dart            ← NEW: brightness/contrast/saturation/hue
│   ├── player_button_editor.dart           ← NEW: enable/disable + reorder buttons
│   ├── player_controls_bar.dart            ← NEW: bottom control bar (customizable)
│   ├── ambilight_glow_border.dart          ← NEW: animated glow ring around video
│   ├── transparent_player_overlay.dart     ← NEW: ghost/see-through player controls
│   ├── scene_bookmarks_panel.dart          ← NEW: bookmark list + add bookmark UI
│   ├── binge_guard_overlay.dart            ← NEW: take-a-break screen
│   └── episode_recap_sheet.dart            ← NEW: "play last 60s of prev episode" prompt
```

---

## 2. Player Preferences Model (`player_prefs.dart`)

All prefs stored in SharedPreferences with prefix `player_`.

```dart
class PlayerPrefs {
  // ── GESTURE SETTINGS ─────────────────────────────────────────
  bool gestureEnabled;           // master gesture toggle (default: true)
  bool swipeBrightnessEnabled;   // left-half swipe = brightness (default: true)
  bool swipeVolumeEnabled;       // right-half swipe = volume (default: true)
  bool swipeSeekEnabled;         // horizontal swipe = seek (default: true)
  bool doubleTapSeekEnabled;     // double-tap left/right to seek (default: true)
  int doubleTapSeekSeconds;      // 5/10/15/20/30 (default: 10)
  bool longPressSpeedEnabled;    // long-press for speed boost (default: true)
  double longPressSpeed;         // 1.5/2.0/2.5/3.0 (default: 2.0)
  bool pinchZoomEnabled;         // pinch to zoom (default: true)
  double swipeSensitivity;       // 0.5 – 2.0 (default: 1.0)
  double seekSensitivity;        // 0.5 – 2.0 (default: 1.0)
  double gestureZoneWidth;       // % of screen for left/right zones (default: 0.4 = 40%)
  bool rageSkipEnabled;          // triple-tap center for mega-skip (default: true)
  int rageSkipSeconds;           // 60/120/180/300 (default: 120)

  // ── CONTROL BAR SETTINGS ─────────────────────────────────────
  List<String> topBarButtons;
  List<String> bottomBarButtons;
  double buttonSize;             // 0.8 – 1.4 scale (default: 1.0)
  double controlBarOpacity;      // 0.3 – 1.0 (default: 0.85)
  int autoHideSeconds;           // 2/3/5/10/0=never (default: 3)
  bool showSeekBar;
  bool showTimeElapsed;
  bool showTimeRemaining;
  bool showChapterMarkers;
  bool showThumbnailPreview;     // local/downloaded files only
  bool showBufferBar;
  bool compactTopBar;
  String seekBarThumbStyle;      // 'dot' / 'line' / 'circle' (default: 'circle')

  // ── SUBTITLE SETTINGS ────────────────────────────────────────
  bool subtitleAutoDetect;       // auto-detect .srt/.ass in same folder — local files only
  String subtitleEncoding;       // 'utf-8' / 'latin1' / 'windows-1252' / 'auto' (default: 'auto')
  double subtitleFontSize;       // 10 – 40 (default: 18)
  String subtitleFontFamily;     // 'Sans-Serif' / 'Serif' / 'Monospace' (default: 'Sans-Serif')
  bool subtitleBold;
  bool subtitleItalic;
  Color subtitleTextColor;       // (default: Colors.white)
  Color subtitleOutlineColor;    // (default: Colors.black)
  double subtitleOutlineThickness; // 0 – 4 (default: 2.0)
  Color subtitleBackgroundColor;
  double subtitleBackgroundOpacity; // 0 – 1 (default: 0.0)
  String subtitlePosition;       // 'bottom' / 'top' / 'center' (default: 'bottom')
  double subtitleVerticalOffset; // % from edge (default: 0.1)
  int subtitleTimingOffsetMs;    // -5000 – +5000 ms (default: 0)
  bool subtitleEnabled;

  // ── AUDIO SETTINGS ───────────────────────────────────────────
  int audioTimingOffsetMs;       // -5000 – +5000 ms (default: 0)
  double volumeBoost;            // 1.0 – 3.0 (100%–300%) (default: 1.0)
  bool equalizerEnabled;
  String equalizerPreset;        // 'flat'/'rock'/'pop'/'bass'/'movie'/'voice'/'custom' (default: 'flat')
  List<double> equalizerBands;   // 10 values: -12.0 to +12.0 dB
  bool audioNormalization;
  bool stereoMono;               // false=stereo, true=mono (default: false)
  double audioBalance;           // -1.0 (left) to +1.0 (right) (default: 0.0)
  bool dialogueBoostEnabled;     // voice clarity mode — boosts 300Hz–3kHz (default: false)

  // ── VIDEO ENHANCEMENT ────────────────────────────────────────
  double brightness;             // -0.5 – +0.5 (default: 0.0)
  double contrast;               // -0.5 – +0.5 (default: 0.0)
  double saturation;             // -0.5 – +0.5 (default: 0.0)
  double hue;                    // -180 – +180 degrees (default: 0.0)
  bool nightMode;
  double nightModeIntensity;     // 0.1 – 1.0 (default: 0.5)
  bool sharpnessEnabled;
  double sharpness;              // 0.0 – 1.0 (default: 0.3)

  // ── PLAYBACK SETTINGS ────────────────────────────────────────
  double playbackSpeed;
  bool rememberSpeed;
  bool rememberPosition;
  bool autoPlayNext;
  int nextEpisodeCountdown;      // 5/10/15 seconds (default: 10)
  bool hwDecoderEnabled;
  bool backgroundPlayEnabled;
  bool preventScreenOff;
  bool autoRotate;

  // ── SMART SKIP INTRO ─────────────────────────────────────────
  // Series intro times are stored separately in SmartIntroStore (SharedPrefs JSON map)
  // Key: series_id (String), Value: intro_end_seconds (int)
  bool autoSkipIntroEnabled;     // auto-skip without showing button (default: false)
  bool showSkipIntroButton;      // show button when intro time is known (default: true)

  // ── TRANSPARENT / GHOST PLAYER ───────────────────────────────
  bool transparentModeEnabled;          // (default: false)
  double transparentModeOpacity;        // 0.2 – 1.0 (default: 0.5)
  bool transparentModeFrostedControls;  // frosted glass on control overlay (default: true)

  // ── AMBILIGHT MODE ───────────────────────────────────────────
  bool ambilightEnabled;                // (default: false)
  double ambilightIntensity;            // 0.3 – 1.0 (default: 0.7)
  double ambilightBlurRadius;           // 20 – 80 (default: 40)
  int ambilightSampleIntervalMs;        // 200 – 1000ms (default: 400)

  // ── BINGE GUARD ──────────────────────────────────────────────
  bool bingeGuardEnabled;               // (default: false)
  int bingeGuardThresholdMinutes;       // 60/90/120/180 (default: 120)

  // ── SLEEP FADE ───────────────────────────────────────────────
  bool sleepFadeEnabled;                // fade volume before stop (default: true)
  int sleepFadeDurationSeconds;         // 15/30/60 (default: 30)

  // ── SCENE BOOKMARKS ──────────────────────────────────────────
  // Bookmarks are stored in SQLite, not SharedPrefs (see SceneBookmarkStore)
  bool bookmarkVibrate;                 // haptic when bookmark saved (default: true)

  // ── MODES ────────────────────────────────────────────────────
  bool cinematicModeOnLock;
  bool gesturesInCinematic;
  String cinematicTapBehavior;          // 'pause_resume' / 'show_controls' (default: 'pause_resume')

  // ── UI APPEARANCE ─────────────────────────────────────────────
  String accentColor;                   // hex (default: '#E8002D')
  double uiFontSize;                    // 0.8 – 1.2 scale (default: 1.0)
  bool showEpisodeInfo;
  bool showNetworkSpeed;
  bool showDecoderInfo;
  bool vibrateOnGesture;
}
```

---

## 3. Feature Specifications

### 3.1 Gesture System (configurable)

**Zone layout (configurable width, default 40%/20%/40%):**
```
┌─────────────────────────────────────────┐
│  LEFT ZONE   │  CENTER ZONE │ RIGHT ZONE │
│  (Brightness)│  (Tap/Seek)  │  (Volume)  │
└─────────────────────────────────────────┘
```

**All gestures:**
| Gesture | Action | Configurable |
|---|---|---|
| Swipe up/down left zone | Brightness ±% | ✅ disable, sensitivity |
| Swipe up/down right zone | Volume ±% | ✅ disable, sensitivity |
| Swipe horizontal anywhere | Seek ±seconds | ✅ disable, sensitivity |
| Double-tap left zone | Seek back N seconds | ✅ N = 5/10/15/20/30 |
| Double-tap right zone | Seek forward N seconds | ✅ N = 5/10/15/20/30 |
| Double-tap center | Play/Pause | ✅ enable/disable |
| Single tap center | Show/hide controls | always |
| Long-press | Speed boost (hold) | ✅ disable, speed value |
| Pinch | Zoom in/out | ✅ disable |
| Triple-tap center | Rage Skip | ✅ enable/disable, seconds |
| Swipe from left edge | Chapter prev | ✅ enable/disable |
| Swipe from right edge | Chapter next | ✅ enable/disable |

**Visual feedback:**
- Brightness/volume: centered pill with icon + bar + % value
- Seek: centered pill with `MM:SS (±Ns)` and arrow animation
- Zoom: top-center badge showing `1.2×`
- Double-tap: ripple animation + seek flash overlay
- **Rage Skip**: full-width red flash + "RAGE SKIP ⚡ +2:00" badge

---

### 3.2 Cinematic Mode

Cinematic mode is a "pure focus" state — UI completely disappears, only video remains. Gestures still work.

**Entry:**
- Tap the lock button (if `prefs.cinematicModeOnLock = true`)
- OR tap a dedicated "Cinematic" button in top bar

**Behavior:**
- All controls, seek bar, top bar hidden completely
- Status bar hidden
- Black bars behind video are fully black (no UI chrome)
- Gestures still active (brightness, volume, seek)
- If `cinematicTapBehavior = 'pause_resume'`: single tap = play/pause (no controls shown)
- If `cinematicTapBehavior = 'show_controls'`: single tap shows controls for 2s then hides

**Exit:**
- Swipe from bottom edge → shows a minimal strip (seek bar + play/pause + time) for 3s
- Tap lock/cinematic button again

---

### 3.3 Smart Skip Intro

**Rules — when to show:**
- ✅ Show for: `series`, `drama`, `anime`, `donghua`, `cartoon`, `show`
- ❌ Never show for: `movie`, `song`, `clip`, `short`, `documentary`, `music_video`
- ❌ Never show if video duration < 10 minutes
- The content type comes from the catalog data passed to `PlayerScreen`

**Smart per-series memory (`SmartIntroStore`):**
```dart
class SmartIntroStore {
  // Key: series_id (String)
  // Value: intro_end_seconds (int)
  // Stored: SharedPrefs as JSON map under 'player_intro_times'

  Future<int?> getIntroTime(String seriesId);
  Future<void> saveIntroTime(String seriesId, int seconds);
  Future<void> clearIntroTime(String seriesId);
}
```

**Flow:**
1. User is watching episode of a series
2. If `SmartIntroStore` has a saved intro time for this `series_id`:
   - At that timestamp: show "Skip Intro" button (or auto-skip if `autoSkipIntroEnabled`)
   - Small "Reset" icon next to button lets user clear the saved time
3. If no saved time yet:
   - No skip intro button shown by default
   - After first play, show one-time tooltip: "Long-press seek bar to set intro end time"
   - When user manually taps Skip Intro at any point: save current position as intro time for this series
4. Saved intro times apply to ALL episodes of that series (they all have the same intro)

**Manual set:**
- Long-press seek bar → context menu with "Set intro end here" option
- Saves current position as intro_end_seconds for this series

**UI:**
```
┌─────────────────────────────────────────────┐
│                                              │
│                                   [Skip Intro ↺]  │
│                                              │
└─────────────────────────────────────────────┘
```
Bottom-right corner, pill button. Tapping skips to `intro_end_seconds`. Long-pressing the button → "Clear saved time for this series".

---

### 3.4 A-B Loop

User sets point A (start) and point B (end). Player loops between them until user cancels.

**UI (bottom control bar when active):**
```
[A●] ──────────────────────── [●B]  [✕ Loop]
```
- Tap A-B button → set A at current position, button turns orange
- Tap again → set B at current position, loop begins, button turns red
- Tap again → clear loop

**Behavior:**
- When position reaches B: seek back to A and continue
- Seek bar shows A and B markers as colored dots

---

### 3.5 Subtitle System

**Auto-detect (local files only):**
- Scan same directory as video for `.srt` `.ass` `.ssa` `.vtt` `.sub`
- Add found files to subtitle track list
- For streaming URLs: not applicable (no local directory)

**Styling panel (accessible from subtitle track button → "Style" tab):**
- Font size slider (10–40)
- Font family picker (Sans-Serif / Serif / Monospace)
- Bold / Italic toggles
- Text color picker (flutter_colorpicker)
- Outline color + thickness slider
- Background color + opacity slider
- Position: Bottom / Top / Center
- Vertical offset slider

**Timing:**
- Subtitle delay slider: -5000ms to +5000ms (shown in subtitle panel)
- Changes take effect immediately via MPV `sub-delay` property

**Encoding:**
- Auto-detect via charset detection
- Manual override: UTF-8 / Latin-1 / Windows-1252

---

### 3.6 Audio System

**Equalizer (10-band):**
- Bands: 60Hz / 170Hz / 310Hz / 600Hz / 1kHz / 3kHz / 6kHz / 12kHz / 14kHz / 16kHz
- Gain: -12dB to +12dB per band
- Presets: Flat / Rock / Pop / Bass Boost / Movie / Voice / Custom
- Applied via MPV `af=equalizer=...` filter chain

**Dialogue Boost (Voice Clarity Mode):**
- One-tap toggle in quick settings panel
- Applies a fixed EQ preset targeting human voice frequencies:
  - 60Hz: 0dB, 170Hz: 0dB, 310Hz: +2dB, 600Hz: +4dB
  - 1kHz: +5dB, 3kHz: +4dB, 6kHz: +2dB, 12kHz: 0dB, 14kHz: 0dB, 16kHz: 0dB
- Cannot be active at the same time as custom EQ (one overrides the other)
- Perfect for Pakistani dramas where dialogue clarity matters

**Volume Boost:**
- System volume at max + MPV volume property above 100
- Range: 100%–300%
- `VolumeController.instance.maxVolume()` + `player.setProperty('volume', '${boost * 100}')`

**Audio delay:** MPV `audio-delay` property, -5000ms to +5000ms

**Audio normalization:** MPV `dynaudnorm` filter, toggle on/off

**Stereo/Mono + Balance:** MPV `pan` audio filter

---

### 3.7 Video Enhancement

Applied via MPV `vf=eq=brightness=X:contrast=Y:saturation=Z:gamma=1.0` filter.

| Setting | Range | MPV property |
|---|---|---|
| Brightness | -0.5 – +0.5 | `eq=brightness=` |
| Contrast | -0.5 – +0.5 | `eq=contrast=` |
| Saturation | -0.5 – +0.5 | `eq=saturation=` |
| Hue | -180 – +180° | `eq=hue=` (convert to 0.0–1.0 for MPV) |
| Night Mode | warm amber tint | `colorchannelmixer` filter |
| Sharpness | 0.0 – 1.0 | `unsharp` filter |

All filters stack: combine all active filters into one `vf=` string and set once.

Night mode MPV string:
```dart
'colorchannelmixer=rr=0.9:rg=0.1:rb=0.05:gr=0.01:gg=0.8:gb=0.05:br=0:bg=0:bb=0.7'
```

---

### 3.8 Transparent / Ghost Player Mode ★ NEW — Never Seen Before

A mode where the video plays at a configurable opacity, letting you see through it. The control overlay uses frosted glass. Think "watching while working" — video ghosted over your home screen content.

**Activation:**
- Button in top bar (ghost icon) OR in quick settings panel
- Entering this mode does NOT pause playback

**Behavior:**
```
┌────────────────────────────────────────┐
│  [Opacity slider]  20% ──●────── 100%  │
│                                        │
│  ░░░░░ VIDEO (semi-transparent) ░░░░░  │
│  ░░░░░ (device content shows  ) ░░░░░  │
│  ░░░░░ through behind video   ) ░░░░░  │
│                                        │
│  [Frosted glass control bar]           │
└────────────────────────────────────────┘
```

**Implementation:**
```dart
// Wrap VideoWidget in Opacity
Opacity(
  opacity: prefs.transparentModeOpacity,  // 0.2 – 1.0
  child: Video(controller: _videoCtrl),
)

// Controls use BackdropFilter frosted glass
ClipRRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      color: Colors.black.withOpacity(0.3),
      child: _ControlsBar(),
    ),
  ),
)
```

**Opacity quick-slider:**
- Shown as a horizontal mini-slider directly in the player when transparent mode is active
- Position: bottom-left corner, small pill
- Range: 20% – 100%

**Use cases users love:**
- Watch a drama while pretending to look at something else
- Watch while reading chat messages behind the video
- Create a "wallpaper" effect with looping video content

---

### 3.9 Ambilight Glow Mode ★ NEW — Never Seen Before in Mobile Streaming

Inspired by Philips Ambilight TVs. The player samples the colors at the edges of the current video frame and projects a matching colored glow around the outside of the video. The glow updates in real time as the scene changes.

**What it looks like:**
```
    🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦🟦
  🟦                            🟦
  🟦  ┌──────────────────────┐  🟦   ← glow matches current
  🟦  │   VIDEO PLAYING      │  🟦     scene colors
  🟦  │   (sunset scene)     │  🟦
  🟦  └──────────────────────┘  🟦
  🟫🟫                        🟫🟫
    🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫🟫
```

**Implementation (`AmbiLightController`):**
```dart
class AmbiLightController {
  Timer? _sampleTimer;
  Color _topColor = Colors.black;
  Color _bottomColor = Colors.black;
  Color _leftColor = Colors.black;
  Color _rightColor = Colors.black;

  void start(Player player, int intervalMs) {
    _sampleTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) async {
      final frame = await player.screenshot(); // Uint8List?
      if (frame == null) return;
      // Decode image and sample edge pixel strips
      final img = await decodeImageFromList(frame);
      _topColor = await _sampleStrip(img, edge: 'top');
      _bottomColor = await _sampleStrip(img, edge: 'bottom');
      _leftColor = await _sampleStrip(img, edge: 'left');
      _rightColor = await _sampleStrip(img, edge: 'right');
      notifyListeners();
    });
  }
}
```

**The glow widget (`AmbiLightGlowBorder`):**
```dart
// Wrap the entire player in a Container with animated gradient box shadow
AnimatedContainer(
  duration: Duration(milliseconds: 300),
  decoration: BoxDecoration(
    boxShadow: [
      BoxShadow(color: _ctrl.topColor.withOpacity(intensity), blurRadius: blur, offset: Offset(0, -blur/2)),
      BoxShadow(color: _ctrl.bottomColor.withOpacity(intensity), blurRadius: blur, offset: Offset(0, blur/2)),
      BoxShadow(color: _ctrl.leftColor.withOpacity(intensity), blurRadius: blur, offset: Offset(-blur/2, 0)),
      BoxShadow(color: _ctrl.rightColor.withOpacity(intensity), blurRadius: blur, offset: Offset(blur/2, 0)),
    ],
  ),
  child: VideoPlayerStack(),
)
```

**Settings:**
- Intensity: 30% – 100%
- Blur radius: 20px – 80px
- Sample rate: every 200ms / 400ms / 800ms (default: 400ms)
- Toggle: in quick settings panel

---

### 3.10 Binge Guard ★ NEW

Tracks total continuous watch time in the current app session. After a user-set threshold, shows a friendly break reminder screen. Fully dismissable — never blocks content.

**Trigger:**
- After N minutes of active playback (paused time does not count)
- Default threshold: 2 hours (configurable: 1h / 1.5h / 2h / 3h / off)

**Break screen overlay (full-screen, semi-transparent):**
```
┌────────────────────────────────────────┐
│                                        │
│        👀  You've watched              │
│         2 hours straight!              │
│                                        │
│    🎬  12 episodes today               │
│    ⏱  First episode: 6:30 PM          │
│    👁  Total today: 3h 20m             │
│                                        │
│    [Take a 10min break]                │
│    [Keep watching — I'm fine]          │
│                                        │
└────────────────────────────────────────┘
```

- "Take a break" → pauses player, exits to app home
- "Keep watching" → dismisses, resets timer (so next reminder is N hours later)
- Stats are for current app session only, never stored permanently

---

### 3.11 Sleep Fade ★ NEW — Smarter Sleep Timer

The current sleep timer stops abruptly. Sleep Fade makes it gradual and pleasant.

**Behavior (when `sleepFadeEnabled = true`):**
1. Sleep timer is set (e.g., 30 minutes)
2. At T-30 seconds: badge shows "Sleeping in 30s..."
3. MPV volume smoothly fades from current → 0 over the fade duration
4. At T-0: playback pauses, volume restored to original
5. Optional: at T-60s show a soft "Going to sleep soon..." toast

**Implementation:**
```dart
void _startSleepFade(int secondsUntilSleep) {
  final steps = prefs.sleepFadeDurationSeconds; // 15/30/60
  final originalVolume = _currentVolume;
  final stepInterval = Duration(milliseconds: (steps * 1000) ~/ 100);
  
  Timer.periodic(stepInterval, (t) {
    if (!mounted) { t.cancel(); return; }
    final progress = t.tick / 100.0;
    final newVol = originalVolume * (1.0 - progress);
    player.setProperty('volume', '${(newVol * 100).toInt()}');
    if (t.tick >= 100) {
      t.cancel();
      player.pause();
      player.setProperty('volume', '${(originalVolume * 100).toInt()}'); // restore
    }
  });
}
```

**Settings:** fade duration: 15s / 30s / 60s. Toggle on/off.

---

### 3.12 Scene Bookmarks ★ NEW

Save any moment in a video with an emoji label. Browse all bookmarks for an episode in a slide-up panel.

**Adding a bookmark:**
- Long-press the seek bar at any position → "Bookmark this moment" snackbar appears with emoji picker
- Emoji options: ❤️ 🔥 😂 😮 💔 📌 ⭐ 🎯
- Tap an emoji → bookmark saved with current timestamp + emoji + content_id + episode_id

**Viewing bookmarks:**
- Seek bar shows small colored dot for each saved bookmark
- Tap the bookmark icon in top bar → slide-up panel:
  ```
  ┌─── Bookmarks ──────────────────────────────┐
  │  ❤️  24:15  (tap to seek)                  │
  │  🔥  47:32                                  │
  │  😂  1:02:10                                │
  │  ────────────────                           │
  │  [+ Add bookmark at current time]          │
  └────────────────────────────────────────────┘
  ```
- Tap any bookmark → seeks to that position
- Long-press bookmark → delete

**Storage (`SceneBookmarkStore` → SQLite):**
```dart
// Table: scene_bookmarks
// Columns: id, content_id, episode_id, position_ms, emoji, created_at
```

---

### 3.13 Rage Skip ★ NEW

Triple-tap the center of the player to instantly skip forward a large amount (default: 2 minutes). For when a scene gets boring and you just want to move past it.

**Activation:** Triple-tap center zone within 600ms

**Visual feedback:**
- Full-screen red flash for 200ms
- Large animated badge: `"RAGE SKIP ⚡  +2:00"` slides in from center, fades out in 1 second

**Implementation:**
```dart
int _centerTapCount = 0;
Timer? _tapResetTimer;

void _onCenterTap() {
  _centerTapCount++;
  _tapResetTimer?.cancel();
  _tapResetTimer = Timer(Duration(milliseconds: 600), () => _centerTapCount = 0);
  
  if (_centerTapCount >= 3) {
    _centerTapCount = 0;
    _tapResetTimer?.cancel();
    final skipTo = _position + Duration(seconds: prefs.rageSkipSeconds);
    _player.seek(skipTo > _duration ? _duration : skipTo);
    _showRageSkipAnimation();
    HapticFeedback.heavyImpact();
  }
}
```

**Settings:** enable/disable, skip duration: 1min / 2min / 3min / 5min

---

### 3.14 Episode Recap Preview ★ NEW

Before starting episode N (when N > 1), offer to play the last 60 seconds of the previous episode as a recap. Optional, dismissable, never auto-plays.

**When it appears:**
- Opening episode 2, 3, 4… of a series
- Only shown if episode N-1 was previously watched (has a saved position = near end)
- Bottom sheet slides up at the START of the new episode (after first 2 seconds)

**UI:**
```
┌─── Quick Recap? ───────────────────────────┐
│  Play the last minute of Episode 5?        │
│  (Ep 5: Drama Title — 44:10 – 45:10)       │
│                                            │
│  [▶ Play Recap (1:00)]   [Skip, I remember]│
└────────────────────────────────────────────┘
```

**Behavior:**
- "Play Recap" → seeks current player to (duration - 60s) of previous episode URL, plays for 60s, then auto-jumps to episode N from beginning
- "Skip, I remember" → dismisses sheet, episode N plays normally
- Sheet auto-dismisses after 8 seconds if no input

---

## 4. PlayerSettingsScreen Layout

Full settings screen opened via gear icon → "Full Settings →" from quick panel.

```
PlayerSettingsScreen (full page)
├── Gestures
│   ├── Master gesture toggle
│   ├── Brightness swipe (enable/sensitivity)
│   ├── Volume swipe (enable/sensitivity)
│   ├── Seek swipe (enable/sensitivity)
│   ├── Double-tap seek seconds
│   ├── Long-press speed
│   ├── Gesture zone width
│   └── Rage Skip (enable/seconds)
├── Controls
│   ├── Button size
│   ├── Control bar opacity
│   ├── Auto-hide timer
│   ├── Show/hide each button (checkboxes)
│   └── Seek bar options (thumb style, buffer bar, time format)
├── Subtitles
│   ├── Font size / family / bold / italic
│   ├── Text color / outline / background
│   ├── Position + vertical offset
│   ├── Timing offset
│   └── Auto-detect (local files)
├── Audio
│   ├── Equalizer (10-band + presets)
│   ├── Dialogue Boost toggle
│   ├── Volume boost slider
│   ├── Audio delay
│   ├── Normalization
│   └── Stereo/Mono + balance
├── Video
│   ├── Brightness / Contrast / Saturation / Hue sliders
│   ├── Night Mode (toggle + intensity)
│   └── Sharpness
├── New Features
│   ├── Ambilight (toggle + intensity + blur + speed)
│   ├── Transparent Player (toggle + opacity slider)
│   ├── Binge Guard (toggle + threshold)
│   ├── Sleep Fade (toggle + duration)
│   └── Rage Skip (toggle + seconds)
├── Playback
│   ├── Speed + remember speed
│   ├── Resume position
│   ├── Auto-play next episode
│   ├── Next episode countdown
│   ├── Hardware decoder
│   └── Background audio
└── Appearance
    ├── Accent color picker
    ├── UI font scale
    └── Info badges (network speed, decoder info)
```

---

## 5. Quick Settings Panel (In-Player)

Gear icon in top bar → bottom sheet:

```
┌─── Player Settings ──────────────────────────────┐
│  Gestures      [═══════● On]                     │
│  Subtitles     [═════●   On]   Style →           │
│  Sub Size      [────●────] 18px                  │
│  Speed         [0.75 / 1.0● / 1.25 / 1.5 / 2.0] │
│  Dialogue Boost [●       Off]                    │
│  Night Mode    [●         Off]                   │
│  Volume Boost  [──●──────] 100%                  │
│  Ambilight     [●         Off]                   │
│  Transparent   [●         Off]  Opacity →        │
│  Auto-Hide     [3s ●] 5s / 10s                   │
│  Cinematic     [●         Off]                   │
│  Binge Guard   [═══════● On]                     │
│                                                  │
│  [ Full Settings →]          [Done]              │
└──────────────────────────────────────────────────┘
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

## 7. Player Modes Summary

| Mode | Controls | Gestures | Status bar |
|---|---|---|---|
| Normal | Visible (auto-hide) | ✅ | Hidden |
| Cinematic | Hidden | ✅ | Hidden |
| Locked | Hidden | ❌ | Hidden |
| Transparent | Frosted glass | ✅ | Hidden |
| Background | — | — | System |
| PiP | Mini controls | ❌ | System |

---

## 8. Skip Intro — Content Type Reference

| content_type value | Show skip intro? |
|---|---|
| `series` | ✅ Yes |
| `drama` | ✅ Yes |
| `anime` | ✅ Yes |
| `donghua` | ✅ Yes |
| `cartoon` | ✅ Yes |
| `show` | ✅ Yes |
| `movie` | ❌ No |
| `song` | ❌ No |
| `clip` | ❌ No |
| `short` | ❌ No |
| `documentary` | ❌ No |
| `music_video` | ❌ No |
| duration < 10min | ❌ No (regardless of type) |

The `content_type` field must be passed from catalog data into `PlayerScreen` as a parameter.

---

## 9. Implementation Priority Order

### Phase 3A — Foundation (do this first)
1. Create `player_prefs.dart` + `PlayerPrefs` model
2. Create `player_prefs_provider.dart` (Riverpod StateNotifier)
3. Wire `ref.watch(playerPrefsProvider)` into `player_screen.dart`
4. Replace hardcoded gesture values with prefs values

### Phase 3B — Controls & Settings UI
1. Create `player_settings_screen.dart`
2. Quick settings bottom sheet (gear icon)
3. Button show/hide checkboxes
4. Auto-hide timer + seek bar options

### Phase 3C — Smart Skip Intro
1. Create `smart_intro_store.dart`
2. Pass `content_type` parameter to PlayerScreen
3. Implement content-type check (show only for series types)
4. Save intro time when user taps skip
5. Auto-show/auto-skip for known series

### Phase 3D — Subtitle System
1. Subtitle timing offset slider
2. Subtitle style panel (font, color, outline, position)
3. Auto-detect for local files

### Phase 3E — Cinematic Mode
1. `cinematic_overlay.dart` widget
2. Lock button behavior (configurable)
3. Gesture-in-cinematic logic

### Phase 3F — Audio & Video Enhancement
1. Audio delay slider
2. Volume boost
3. 10-band EQ + Dialogue Boost
4. Video filters (brightness/contrast/saturation/hue/night mode)
5. Audio normalization

### Phase 3G — New Original Features (implement in this order)
1. **Sleep Fade** — easiest, high impact, 50 lines of code
2. **Rage Skip** — very fast to implement, users will love it
3. **Scene Bookmarks** — SQLite + seek bar dots + panel
4. **Ambilight Mode** — screenshot sampling + glow widget
5. **Transparent Player** — Opacity widget + BackdropFilter
6. **Binge Guard** — timer + overlay screen
7. **Episode Recap Preview** — needs prev episode URL access

### Phase 3H — Advanced
1. A-B Loop
2. Frame-by-frame
3. Chapter markers on seek bar
4. Seek thumbnail preview (local files only)
5. Screenshot to gallery

### Phase 4 (future, not this agent)
- Button drag-to-reorder editor (complex Flutter UI)
- OpenSubtitles search (needs API key from user)
- Auto intro time detection (audio fingerprinting — very complex)

---

## 10. Implementation Notes & MPV Commands

```dart
// Equalizer (audio filter)
await player.setProperty('af', 
  'equalizer=f=60:width_type=o:width=2:g=${bands[0]},'
  'equalizer=f=170:width_type=o:width=2:g=${bands[1]},'
  'equalizer=f=310:width_type=o:width=2:g=${bands[2]},'
  'equalizer=f=600:width_type=o:width=2:g=${bands[3]},'
  'equalizer=f=1000:width_type=o:width=2:g=${bands[4]},'
  'equalizer=f=3000:width_type=o:width=2:g=${bands[5]},'
  'equalizer=f=6000:width_type=o:width=2:g=${bands[6]},'
  'equalizer=f=12000:width_type=o:width=2:g=${bands[7]},'
  'equalizer=f=14000:width_type=o:width=2:g=${bands[8]},'
  'equalizer=f=16000:width_type=o:width=2:g=${bands[9]}',
);

// Video filters (combine all active filters into one vf= call)
String buildVfString(PlayerPrefs prefs) {
  final parts = <String>[];
  final hasBCH = prefs.brightness != 0 || prefs.contrast != 0 
               || prefs.saturation != 0 || prefs.hue != 0;
  if (hasBCH) {
    parts.add('eq=brightness=${prefs.brightness}:contrast=${1.0 + prefs.contrast}:'
              'saturation=${1.0 + prefs.saturation}:hue=${prefs.hue / 180.0}');
  }
  if (prefs.nightMode) {
    final i = prefs.nightModeIntensity;
    parts.add('colorchannelmixer=rr=${0.9+i*0.05}:rg=${0.1*i}:rb=${0.05*i}:'
              'gr=${0.01*i}:gg=${0.8+i*0.05}:gb=${0.05*i}:br=0:bg=0:bb=${0.7+i*0.1}');
  }
  if (prefs.sharpnessEnabled) {
    parts.add('unsharp=la=${prefs.sharpness * 2}:ca=${prefs.sharpness}');
  }
  return parts.join(',');
}
await player.setProperty('vf', buildVfString(prefs));

// Volume boost above 100%
VolumeController.instance.maxVolume();
await player.setProperty('volume', '${(prefs.volumeBoost * 100).toInt()}');

// Audio delay
await player.setProperty('audio-delay', '${prefs.audioTimingOffsetMs / 1000.0}');

// Subtitle delay
await player.setProperty('sub-delay', '${prefs.subtitleTimingOffsetMs / 1000.0}');

// Hardware decoder
await player.setProperty('hwdec', prefs.hwDecoderEnabled ? 'auto' : 'no');

// Playback speed
await player.setRate(prefs.playbackSpeed);

// Frame step
await player.command(['frame-step']);
await player.command(['frame-back-step']);

// Screenshot (for ambilight + gallery save)
final Uint8List? frame = await player.screenshot();
```

**SharedPrefs persistence pattern:**
```dart
class PlayerPrefsNotifier extends StateNotifier<PlayerPrefs> {
  static const _prefix = 'player_';
  
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = PlayerPrefs(
      doubleTapSeekSeconds: prefs.getInt('${_prefix}dbl_tap_seek') ?? 10,
      gestureZoneWidth: prefs.getDouble('${_prefix}gesture_zone') ?? 0.4,
      rageSkipEnabled: prefs.getBool('${_prefix}rage_skip') ?? true,
      rageSkipSeconds: prefs.getInt('${_prefix}rage_skip_sec') ?? 120,
      dialogueBoostEnabled: prefs.getBool('${_prefix}dialogue_boost') ?? false,
      ambilightEnabled: prefs.getBool('${_prefix}ambilight') ?? false,
      transparentModeEnabled: prefs.getBool('${_prefix}transparent') ?? false,
      transparentModeOpacity: prefs.getDouble('${_prefix}transparent_opacity') ?? 0.5,
      bingeGuardEnabled: prefs.getBool('${_prefix}binge_guard') ?? false,
      sleepFadeEnabled: prefs.getBool('${_prefix}sleep_fade') ?? true,
      // ... all other fields
    );
  }
}
```

**Subtitle auto-detection (local files only):**
```dart
// Only run this when widget.localPath != null
String basePath = localPath.replaceAll(RegExp(r'\.[^.]+$'), '');
final extensions = ['.srt', '.ass', '.ssa', '.vtt', '.sub', '.smi'];
for (final ext in extensions) {
  final file = File('$basePath$ext');
  if (await file.exists()) {
    // Add to subtitle tracks list
  }
}
```

---

## 11. Packages to Add to `pubspec.yaml`

```yaml
# Screenshot save to gallery (for screenshot feature)
gal: ^2.3.0

# Color picker (subtitle color + accent color)
flutter_colorpicker: ^1.1.0
```

All other needed packages are already in `pubspec.yaml`:
- `media_kit`, `media_kit_video` — video player + MPV
- `shared_preferences` — settings persistence
- `screen_brightness`, `volume_controller` — gesture controls
- `file_picker` — external subtitle picker
- `video_thumbnail` — seek thumbnails (local files)
- `sqflite`, `path_provider` — scene bookmarks storage
- `flutter_animate` — animations (rage skip, ambilight)

---

## 12. Files to Modify in Existing Code

1. **`player_screen.dart`** — add `content_type` parameter, wire PlayerPrefs, add new feature widgets
2. **`player_screen.dart` gesture handler** — replace hardcoded values with prefs values, add rage skip
3. **`player_screen.dart` lock button** — check `cinematicModeOnLock`, enter cinematic or lock
4. **`player_screen.dart` skip intro** — replace with SmartIntroStore logic
5. **`app.dart` routes** — add `'/player-settings': (_) => const PlayerSettingsScreen()`
6. **`pubspec.yaml`** — add `gal` and `flutter_colorpicker`
7. **Wherever PlayerScreen is called** — pass `content_type` from catalog data

---

## 13. Testing Checklist

Before pushing, verify each item:

- [ ] All existing gestures (brightness, volume, seek, double-tap, long-press, zoom) still work
- [ ] PlayerPrefs loads from SharedPrefs on cold start
- [ ] Gesture sensitivity changes take effect immediately
- [ ] Skip intro shows for drama/anime, does NOT show for movies and songs
- [ ] Skip intro time saved per series — applies to next episode automatically
- [ ] Cinematic mode: controls hidden, single tap pause/resumes, gestures still work
- [ ] Lock mode: still works as before
- [ ] Transparent mode: video opacity changes in real time with slider
- [ ] Ambilight: glow color changes with video scene (test with colorful content)
- [ ] Dialogue Boost: voice sounds clearer (enable on a drama scene)
- [ ] Sleep Fade: volume fades smoothly before sleep timer ends
- [ ] Rage Skip: triple-tap center skips forward N minutes with animation
- [ ] Scene Bookmark: long-press seek bar → bookmark saved → dot appears on seek bar
- [ ] Binge Guard: fires at correct threshold (test with low threshold like 1 min for dev)
- [ ] Settings screen: all toggles save and persist across player sessions
- [ ] Build passes: `flutter analyze` shows no errors

