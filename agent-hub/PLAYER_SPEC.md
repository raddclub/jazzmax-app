# RaddFlix Player — Supreme Customizable Player Specification
> **Task for next agent:** Implement everything in this document into `player_screen.dart` and related files.
> **Research basis:** MX Player, VLC, nPlayer, Infuse, KMPlayer, BSPlayer, Kodi, Nova, Just Player, mpv, Potplayer
> **Last updated:** 2026-05-26 Session 7
> **Status:** SPEC ONLY — no code written yet for new features

---

## 0. What Already Exists — DO NOT Rebuild

Current `player_screen.dart` already has:
- ✅ Swipe left = brightness, swipe right = volume, horizontal swipe = seek
- ✅ Double-tap left/right = ±15s seek with flash animation
- ✅ Long-press = 2× speed badge
- ✅ Pinch to zoom + zoom level indicator
- ✅ Zoom reset button (`onResetZoom` callback already wired)
- ✅ Fit/ratio cycling (fit/fill/stretch/16:9/4:3)
- ✅ Lock button (hides controls, tap right edge to unlock)
- ✅ Speed picker panel (slides from right)
- ✅ Audio track selection panel with correct language names (ISO 639 map)
- ✅ Subtitle track selection panel with language names (ISO 639 map)
- ✅ Language name mapping: Urdu, Hindi, Punjabi, Pashto, Sindhi, Arabic, Chinese, Korean, Japanese, etc.
- ✅ Sleep timer panel + badge
- ✅ Skip intro button (**hardcoded at 85s — must be replaced with SmartIntroStore, see §3.3**)
- ✅ Next episode countdown overlay
- ✅ PiP via MethodChannel
- ✅ Chromecast via MethodChannel
- ✅ Buffering indicator
- ✅ Seek scrub label with position preview
- ✅ Seek thumbnail preview (local files)
- ✅ Drag indicator for brightness/volume
- ✅ Resume position saved every 10s to SQLite

Build ON TOP of these. Do not remove them.

---

## 0.1 Platform

**Android only.** No iOS users. All MPV video and audio filters work without restriction.

---

## 1. Architecture — New Files to Create

```
raddflix_flutter/lib/
├── screens/
│   ├── player_screen.dart                  ← existing, expand this
│   └── player_settings_screen.dart         ← NEW
├── core/
│   ├── player/
│   │   ├── player_prefs.dart               ← NEW: all preferences + SharedPrefs persistence
│   │   ├── player_prefs_provider.dart      ← NEW: Riverpod StateNotifier
│   │   ├── subtitle_service.dart           ← NEW: auto-detect + style subtitles
│   │   ├── ab_loop_controller.dart         ← NEW: A-B loop logic
│   │   ├── equalizer_controller.dart       ← NEW: EQ state + media_kit integration
│   │   ├── player_button_layout.dart       ← NEW: button order/visibility model
│   │   ├── smart_intro_store.dart          ← NEW: save/load intro times per series
│   │   ├── ambilight_controller.dart       ← NEW: frame color sampling + glow state
│   │   ├── binge_guard_controller.dart     ← NEW: session watch time tracker
│   │   └── scene_bookmark_store.dart       ← NEW: save/load bookmarks to SQLite
│   └── services/
│       └── subtitle_search_service.dart    ← NEW: OpenSubtitles (needs API key, Phase 4)
├── widgets/player/
│   ├── player_gesture_layer.dart           ← NEW: configurable gesture zones
│   ├── cinematic_overlay.dart              ← NEW: cinematic mode layer
│   ├── subtitle_overlay.dart               ← NEW: styled subtitle rendering
│   ├── seek_thumbnail.dart                 ← NEW: thumbnail on scrub (local only)
│   ├── eq_panel.dart                       ← NEW: 10-band EQ widget
│   ├── ab_loop_panel.dart                  ← NEW: A-B loop controls
│   ├── video_enhance_panel.dart            ← NEW: brightness/contrast/saturation/hue
│   ├── player_button_editor.dart           ← NEW: button enable/disable + reorder
│   ├── player_controls_bar.dart            ← NEW: customizable bottom bar
│   ├── ambilight_glow_border.dart          ← NEW: animated glow ring around video
│   ├── transparent_player_overlay.dart     ← NEW: ghost player controls
│   ├── scene_bookmarks_panel.dart          ← NEW: bookmark list + add UI
│   ├── binge_guard_overlay.dart            ← NEW: take-a-break screen
│   ├── sync_panel.dart                     ← NEW: audio + subtitle delay UI
│   └── track_active_badge.dart             ← NEW: active audio/subtitle pills in header
```

---

## 2. Player Preferences Model (`player_prefs.dart`)

All stored in SharedPreferences with prefix `player_`.

```dart
class PlayerPrefs {
  // ── GESTURE SETTINGS ─────────────────────────────────────────
  bool gestureEnabled;           // master toggle (default: true)
  bool swipeBrightnessEnabled;   // (default: true)
  bool swipeVolumeEnabled;       // (default: true)
  bool swipeSeekEnabled;         // (default: true)
  bool doubleTapSeekEnabled;     // (default: true)
  int doubleTapSeekSeconds;      // 5/10/15/20/30 (default: 10)
  bool longPressSpeedEnabled;    // (default: true)
  double longPressSpeed;         // 1.5/2.0/2.5/3.0 (default: 2.0)
  bool pinchZoomEnabled;         // (default: true)
  double swipeSensitivity;       // 0.5–2.0 (default: 1.0)
  double seekSensitivity;        // 0.5–2.0 (default: 1.0)
  double gestureZoneWidth;       // % of screen 0.3–0.5 (default: 0.4)
  bool rageSkipEnabled;          // triple-tap center (default: true)
  int rageSkipSeconds;           // 60/120/180/300 (default: 120)

  // ── CONTROL BAR SETTINGS ─────────────────────────────────────
  List<String> topBarButtons;
  List<String> bottomBarButtons;
  double buttonSize;             // 0.8–1.4 (default: 1.0)
  double controlBarOpacity;      // 0.3–1.0 (default: 0.85)
  int autoHideSeconds;           // 2/3/5/10/0=never (default: 3)
  bool showSeekBar;
  bool showTimeElapsed;          // (default: true)
  bool showTimeRemaining;        // (default: false)
  bool showChapterMarkers;
  bool showThumbnailPreview;     // local files only
  bool showBufferBar;
  bool compactTopBar;
  String seekBarThumbStyle;      // 'dot'/'line'/'circle' (default: 'circle')
  bool tapTimeToToggle;          // tap time label = toggle elapsed/remaining (default: true)

  // ── SUBTITLE SETTINGS ────────────────────────────────────────
  bool subtitleAutoDetect;       // local files only
  String subtitleEncoding;       // 'auto'/'utf-8'/'latin1'/'windows-1252' (default: 'auto')
  double subtitleFontSize;       // 10–40 (default: 18)
  String subtitleFontFamily;     // (default: 'Sans-Serif')
  bool subtitleBold;
  bool subtitleItalic;
  Color subtitleTextColor;       // (default: Colors.white)
  Color subtitleOutlineColor;    // (default: Colors.black)
  double subtitleOutlineThickness; // 0–4 (default: 2.0)
  Color subtitleBackgroundColor;
  double subtitleBackgroundOpacity; // 0–1 (default: 0.0)
  String subtitlePosition;       // 'bottom'/'top'/'center' (default: 'bottom')
  double subtitleVerticalOffset; // (default: 0.1)
  int subtitleTimingOffsetMs;    // -5000–+5000 ms (default: 0)
  bool subtitleEnabled;

  // ── AUDIO SETTINGS ───────────────────────────────────────────
  int audioTimingOffsetMs;       // -5000–+5000 ms (default: 0)
  double volumeBoost;            // 1.0–3.0 (default: 1.0)
  bool equalizerEnabled;
  String equalizerPreset;        // 'flat'/'rock'/'pop'/'bass'/'movie'/'voice'/'custom'
  List<double> equalizerBands;   // 10 bands: -12.0 to +12.0 dB
  bool audioNormalization;
  bool stereoMono;               // false=stereo, true=mono (default: false)
  double audioBalance;           // -1.0–+1.0 (default: 0.0)
  bool dialogueBoostEnabled;

  // ── TRACK INTELLIGENCE ───────────────────────────────────────
  bool rememberAudioTrack;       // remember last selected audio language (default: true)
  bool rememberSubtitleTrack;    // remember last selected subtitle language (default: true)
  bool autoSelectAudioByLocale;  // auto-pick Urdu/Hindi if device locale matches (default: true)
  bool showActiveTrackBadge;     // show "🎵 Urdu" and "CC English" pills in header (default: true)
  bool showTrackCountBadge;      // show "3A · 2S" badge in header (default: true)
  // Track memory is stored separately in SharedPrefs:
  // 'player_last_audio_lang' → language code string (e.g. 'urd')
  // 'player_last_sub_lang'   → language code string (e.g. 'eng')

  // ── VIDEO ENHANCEMENT ────────────────────────────────────────
  double brightness;             // -0.5–+0.5 (default: 0.0)
  double contrast;               // -0.5–+0.5 (default: 0.0)
  double saturation;             // -0.5–+0.5 (default: 0.0)
  double hue;                    // -180–+180° (default: 0.0)
  bool nightMode;
  double nightModeIntensity;     // 0.1–1.0 (default: 0.5)
  bool sharpnessEnabled;
  double sharpness;              // 0.0–1.0 (default: 0.3)

  // ── PLAYBACK ─────────────────────────────────────────────────
  double playbackSpeed;
  bool rememberSpeed;
  bool rememberPosition;
  bool autoPlayNext;
  int nextEpisodeCountdown;      // 5/10/15 (default: 10)
  bool hwDecoderEnabled;
  bool backgroundPlayEnabled;
  bool preventScreenOff;
  bool autoRotate;
  int seekBackOnResumeSeconds;   // seek back N seconds when app resumes from background (default: 5, 0=off)
  bool longPressPlayRestart;     // long-press play button = restart from beginning (default: false)

  // ── SMART SKIP INTRO ─────────────────────────────────────────
  bool autoSkipIntroEnabled;     // auto-skip without button (default: false)
  bool showSkipIntroButton;      // (default: true)

  // ── TRANSPARENT / GHOST PLAYER ───────────────────────────────
  bool transparentModeEnabled;
  double transparentModeOpacity; // 0.2–1.0 (default: 0.5)
  bool transparentModeFrostedControls;

  // ── AMBILIGHT MODE ───────────────────────────────────────────
  bool ambilightEnabled;
  double ambilightIntensity;     // 0.3–1.0 (default: 0.7)
  double ambilightBlurRadius;    // 20–80 (default: 40)
  int ambilightSampleIntervalMs; // 200–1000 (default: 400)

  // ── BINGE GUARD ──────────────────────────────────────────────
  bool bingeGuardEnabled;
  int bingeGuardThresholdMinutes; // 60/90/120/180 (default: 120)

  // ── SLEEP FADE ───────────────────────────────────────────────
  bool sleepFadeEnabled;          // (default: true)
  int sleepFadeDurationSeconds;   // 15/30/60 (default: 30)

  // ── SCENE BOOKMARKS ──────────────────────────────────────────
  bool bookmarkVibrate;           // (default: true)

  // ── MODES ────────────────────────────────────────────────────
  bool cinematicModeOnLock;
  bool gesturesInCinematic;
  String cinematicTapBehavior;   // 'pause_resume'/'show_controls' (default: 'pause_resume')

  // ── UI APPEARANCE ─────────────────────────────────────────────
  String accentColor;            // hex (default: '#E8002D')
  double uiFontSize;             // 0.8–1.2 (default: 1.0)
  bool showEpisodeInfo;
  bool showNetworkSpeed;
  bool showDecoderInfo;
  bool vibrateOnGesture;

  // ── ORIENTATION ──────────────────────────────────────────────
  String orientationMode;        // 'auto'/'landscape_left'/'landscape_right'/'portrait' (default: 'auto')
}
```

---

## 3. Feature Specifications

### 3.1 Gesture System

**Zone layout (configurable width, default 40% / 20% / 40%):**
```
┌─────────────────────────────────────────┐
│  LEFT ZONE   │  CENTER ZONE │ RIGHT ZONE │
│  (Brightness)│  (Tap/Seek)  │  (Volume)  │
└─────────────────────────────────────────┘
```

| Gesture | Action | Configurable |
|---|---|---|
| Swipe up/down left | Brightness ±% | ✅ disable, sensitivity |
| Swipe up/down right | Volume ±% | ✅ disable, sensitivity |
| Swipe horizontal | Seek ±s | ✅ disable, sensitivity |
| Double-tap left | Seek back N sec | ✅ 5/10/15/20/30 |
| Double-tap right | Seek forward N sec | ✅ 5/10/15/20/30 |
| Double-tap center | Play/Pause | ✅ |
| Single tap center | Show/hide controls | always |
| Long-press | Speed boost (hold) | ✅ disable, speed value |
| Pinch | Zoom | ✅ disable |
| **Triple-tap center** | **Rage Skip** | ✅ disable, seconds |
| Swipe from left edge | Chapter prev | ✅ |
| Swipe from right edge | Chapter next | ✅ |

**Visual feedback:**
- Brightness/volume: pill with icon + bar + % value
- Seek: pill with `MM:SS (±Ns)` and arrow animation
- Zoom: top badge `1.2×`
- Rage Skip: full-screen red flash + `"RAGE SKIP ⚡ +2:00"` badge
- **Volume boost active**: pill shows `🔊 150%` instead of just `%` when MPV volume > 100

---

### 3.2 Cinematic Mode

All controls hidden, gestures still work.

**Entry:** lock button (if `cinematicModeOnLock = true`) OR dedicated button in top bar
**Exit:** swipe from bottom edge → minimal strip (seek + play + time) for 3s, then hides again

- `cinematicTapBehavior = 'pause_resume'`: tap = play/pause (no controls shown)
- `cinematicTapBehavior = 'show_controls'`: tap = controls visible for 2s

---

### 3.3 Smart Skip Intro

**Show only for:** `series`, `drama`, `anime`, `donghua`, `cartoon`, `show`
**Never show for:** `movie`, `song`, `clip`, `short`, `documentary`, `music_video`
**Never show if:** video duration < 10 minutes

PlayerScreen needs a `content_type` parameter (String) from the catalog.

**SmartIntroStore (new file):**
```dart
// SharedPrefs key: 'player_intro_times' → JSON map {series_id: int}
class SmartIntroStore {
  Future<int?> getIntroTime(String seriesId);
  Future<void> saveIntroTime(String seriesId, int seconds);
  Future<void> clearIntroTime(String seriesId);
}
```

**Flow:**
1. No saved time → no button shown. One-time tooltip: "Long-press seek bar to set intro end"
2. User taps Skip Intro at any time → saves current position for this `series_id`
3. Next episode: button appears at saved time, or auto-skips if `autoSkipIntroEnabled`
4. Long-press Skip Intro button → "Clear saved time for this series"
5. Long-press seek bar → context menu "Set intro end here" saves current position

---

### 3.4 A-B Loop

- Tap A-B → set A at current position (button turns orange)
- Tap again → set B, loop begins (button turns red)
- Tap again → clear loop
- Seek bar shows A and B as colored dots

---

### 3.5 Subtitle System

**Auto-detect (local files only):** scan same folder for `.srt` `.ass` `.ssa` `.vtt` `.sub`

**Subtitle panel (from subtitle button) has two tabs:**
- **Tracks** — list of available tracks (with active one highlighted, see §3.15)
- **Style** — font, size, color, outline, background, position
- **Sync** — delay ±ms (see §3.14 for full sync panel spec)
- **Encoding** — manual override: Auto / UTF-8 / Latin-1 / Windows-1252

**Subtitle style settings:**
- Font size (10–40), font family, bold, italic
- Text color, outline color + thickness (0–4)
- Background color + opacity
- Position: Bottom / Top / Center, vertical offset slider

---

### 3.6 Audio System

**Audio panel (from audio button) has two tabs:**
- **Tracks** — list (with active one highlighted)
- **Sync** — delay ±ms (see §3.14)

**Equalizer (10-band):**
Bands: 60Hz / 170Hz / 310Hz / 600Hz / 1kHz / 3kHz / 6kHz / 12kHz / 14kHz / 16kHz
Presets: Flat / Rock / Pop / Bass Boost / Movie / Voice / Custom

**Dialogue Boost (Voice Clarity):**
Fixed EQ preset targeting 300Hz–3kHz (human voice):
`310Hz: +2dB, 600Hz: +4dB, 1kHz: +5dB, 3kHz: +4dB, 6kHz: +2dB`, all others 0
Cannot be active simultaneously with custom EQ.

**Volume Boost:** MPV `volume` property, 100%–300%
**Audio normalization:** MPV `dynaudnorm` filter
**Stereo/Mono + balance:** MPV `pan` filter
**Audio delay:** MPV `audio-delay` (see §3.14)

---

### 3.7 Video Enhancement

MPV `vf=` filter string (combine all active):

| Setting | Range | MPV |
|---|---|---|
| Brightness | -0.5–+0.5 | `eq=brightness=` |
| Contrast | -0.5–+0.5 | `eq=contrast=` |
| Saturation | -0.5–+0.5 | `eq=saturation=` |
| Hue | -180–+180° | `eq=hue=` |
| Night Mode | warm amber | `colorchannelmixer` |
| Sharpness | 0.0–1.0 | `unsharp` |

Build one combined `vf=` string and set once:
```dart
String buildVfString(PlayerPrefs p) {
  final parts = <String>[];
  if (p.brightness != 0 || p.contrast != 0 || p.saturation != 0 || p.hue != 0) {
    parts.add('eq=brightness=${p.brightness}:contrast=${1+p.contrast}:'
              'saturation=${1+p.saturation}:hue=${p.hue/180.0}');
  }
  if (p.nightMode) {
    final i = p.nightModeIntensity;
    parts.add('colorchannelmixer=rr=${0.9+i*0.05}:rg=${0.1*i}:rb=${0.05*i}:'
              'gr=${0.01*i}:gg=${0.8+i*0.05}:gb=${0.05*i}:br=0:bg=0:bb=${0.7+i*0.1}');
  }
  if (p.sharpnessEnabled) parts.add('unsharp=la=${p.sharpness*2}:ca=${p.sharpness}');
  return parts.join(',');
}
```

---

### 3.8 Transparent / Ghost Player Mode ★ NEW

Video plays at configurable opacity. See through it to the content behind.

```dart
Opacity(
  opacity: prefs.transparentModeOpacity,  // 0.2–1.0
  child: Video(controller: _videoCtrl),
)

// Controls: BackdropFilter frosted glass
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

Mini opacity slider in bottom-left corner when mode is active (20%–100%).
Activate via ghost icon in top bar or quick settings panel.

---

### 3.9 Ambilight Glow Mode ★ NEW

Sample video frame edge colors → colored glow around video edges, updates as scene changes.

```dart
// AmbiLightController: Timer.periodic → player.screenshot() → decode → sample edges
// AmbiLightGlowBorder: AnimatedContainer with four BoxShadows (top/bottom/left/right)
```

Settings: intensity (0.3–1.0), blur radius (20–80px), sample rate (200/400/800ms)

---

### 3.10 Binge Guard ★ NEW

After N minutes of active playback: friendly break overlay with session stats.
Stats: episodes watched, hours watched, session start time.
"Take a break" → pause + go home. "Keep watching" → dismiss, reset timer.
Default threshold: 2h. Options: 1h / 1.5h / 2h / 3h / off.

---

### 3.11 Sleep Fade ★ NEW

N seconds before sleep timer ends: smoothly fade MPV volume to 0, then pause.
Restore volume after pause. Duration options: 15s / 30s / 60s. Default: on, 30s.

---

### 3.12 Scene Bookmarks ★ NEW

Long-press seek bar → emoji picker (❤️ 🔥 😂 😮 💔 📌 ⭐ 🎯) → saved to SQLite.
Colored dots on seek bar. Panel from top bar icon: list all, tap to seek, long-press to delete.

```dart
// Table: scene_bookmarks (id, content_id, episode_id, position_ms, emoji, created_at)
```

---

### 3.13 Rage Skip ★ NEW

Triple-tap center (within 600ms) → skip forward N minutes.
Full-screen red flash + `"RAGE SKIP ⚡ +2:00"` badge animation.
Options: 1min / 2min / 3min / 5min. Default: 2min.

---

### 3.14 Audio & Subtitle Synchronization Panel ★ PROPERLY SPECCED

This is one of the most important features for non-native language viewers. MX Player does this well. We must too.

**Access:**
- Audio sync: Audio tracks button → "Sync" tab
- Subtitle sync: Subtitle button → "Sync" tab
- Both also accessible from Quick Settings panel

**UI (same layout for both audio and subtitle):**
```
┌─── Audio Sync ──────────────────────────────────────┐
│                                                      │
│          Audio is delayed by                         │
│              ─200 ms                                 │
│                                                      │
│   [-500]  [-100]  [-50]  [Reset ↺]  [+50]  [+100]  [+500]  │
│                                                      │
│   ◄──────────────●────────────────────► (slider)    │
│  -5000ms                              +5000ms        │
│                                                      │
│  "Tap + or - to shift audio. If you hear speech      │
│   before lips move, tap [+]. If speech is late,      │
│   tap [-]."                                          │
│                                                      │
│                              [Done]                  │
└──────────────────────────────────────────────────────┘
```

**Behavior:**
- ±50ms, ±100ms, ±500ms quick-tap buttons + precise slider
- "Reset ↺" sets delay back to 0ms instantly
- Changes applied to MPV in real time (`audio-delay` or `sub-delay`)
- When delay ≠ 0ms: persistent badge in top bar shows `"Audio −200ms ↺"` or `"Sub +300ms ↺"` — tapping the badge resets to 0 instantly

**Active delay badges in header:**
```dart
// Show these pills in the top bar when delay is non-zero
if (audioDelayMs != 0)
  _SyncBadge(label: 'Audio ${audioDelayMs > 0 ? '+' : ''}${audioDelayMs}ms', onReset: () => _setAudioDelay(0))

if (subDelayMs != 0)
  _SyncBadge(label: 'Sub ${subDelayMs > 0 ? '+' : ''}${subDelayMs}ms', onReset: () => _setSubDelay(0))
```

**MPV commands:**
```dart
await player.setProperty('audio-delay', '${audioDelayMs / 1000.0}');
await player.setProperty('sub-delay', '${subDelayMs / 1000.0}');
```

---

### 3.15 Track Intelligence

**What the code already has (DO NOT rebuild):**
- `_buildAudioLabels()` reads MPV language metadata → shows "Hindi", "Urdu", "English" etc.
- `_buildSubLabels()` does the same for subtitles
- Full ISO 639 language map (Urdu, Hindi, Punjabi, Pashto, Sindhi, Arabic, Chinese, Korean, Japanese, etc.)

**What is missing and must be added:**

**1. Active track highlighted in track picker:**
The current `_TracksPanel` shows all tracks as identical `ListTile`s — no way to tell which is active. Fix:
```dart
// _TracksPanel needs to know the currently active track index
// Show active track with: checkmark icon + bold text + accent color

ListTile(
  title: Text(tracks[i], style: TextStyle(
    color: i == activeIndex ? AppColors.primary : Colors.white,
    fontWeight: i == activeIndex ? FontWeight.bold : FontWeight.normal,
  )),
  trailing: i == activeIndex ? Icon(Icons.check, color: AppColors.primary, size: 18) : null,
  dense: true,
  onTap: () => onSelect(i),
)
```
Pass `activeIndex` to `_TracksPanel` for both audio and subtitle panels.

**2. Active track badge in top bar:**
Small pills in the top bar showing currently active audio language and subtitle.
Only show when `showActiveTrackBadge = true`.
```
┌─────────────────────────────────────────────────────────┐
│  ← Drama Title     🎵 Urdu    CC English    ⚙ 🔊 ···   │
└─────────────────────────────────────────────────────────┘
```
- `🎵 Urdu` — current audio track language
- `CC English` — current subtitle (or `CC Off` when none)
- Tapping either badge opens the respective track picker instantly

**3. Track count badge:**
Show `3A · 2S` small badge in top bar only when multiple tracks exist. Hidden when content has only one audio track and no subtitles.
```dart
final audioCount = _player.state.tracks.audio.length;
final subCount = _player.state.tracks.subtitle.length;
if (audioCount > 1 || subCount > 0)
  _TrackCountBadge(audio: audioCount, subs: subCount)
```

**4. Track memory:**
- When user selects an audio track, save its language code: `prefs.setString('player_last_audio_lang', 'urd')`
- On next content open: auto-select the track matching saved language if present
- Same for subtitle track
- Only if `rememberAudioTrack` / `rememberSubtitleTrack` is enabled

**5. Auto-select by device locale:**
- On first-ever play (no saved preference), check device locale
- If `Locale.languageCode` is `'ur'` → prefer Urdu audio
- If `'hi'` → prefer Hindi audio
- If `'en'` → prefer English audio
- Falls back to first available track if preferred language not found
- Only runs when `autoSelectAudioByLocale = true`

---

### 3.16 Small But Essential Features

These are individually small but collectively make the player feel polished and professional. All other players that users compare us to have these.

---

**A. Seek-Back on App Resume**
When the user leaves the app and comes back (e.g., replied to a message), seek back 5 seconds so they don't miss anything.
```dart
// In didChangeAppLifecycleState:
} else if (state == AppLifecycleState.resumed) {
  if (!_userPaused) {
    WakelockPlus.enable();
    if (prefs.seekBackOnResumeSeconds > 0 && _position.inSeconds > 5) {
      _player.seek(_position - Duration(seconds: prefs.seekBackOnResumeSeconds));
    }
  }
}
```
Default: 5 seconds. Options: Off / 3s / 5s / 10s.

---

**B. Tap Time Label = Jump to Timestamp**
Tapping the current time display opens a bottom sheet with a number pad. User types a time (e.g., `45:20` or `1:23:45`) and seeks there instantly.

```
┌─── Jump to Time ───────────────────────────────┐
│                                                 │
│              [  0  :  4  5  :  2  0  ]         │
│                                                 │
│   [1][2][3]  [4][5][6]  [7][8][9]  [0][⌫]     │
│                                                 │
│              [Jump →]   [Cancel]                │
└─────────────────────────────────────────────────┘
```

---

**C. Tap Time = Toggle Elapsed / Remaining**
If `tapTimeToToggle = true`, tapping the time label (not long-press, just a normal tap) toggles between:
- `12:34` (elapsed)
- `-32:26` (remaining, shown with − prefix)

Implement with a `bool _showRemaining` local state variable toggled on tap.

---

**D. Long-Press Play Button = Restart from Beginning**
If `longPressPlayRestart = true`: long-press the center play/pause button → seeks to position 0.
Shows a brief toast: `"Restarting from beginning"`.
Default: off (too easy to trigger accidentally).

---

**E. Android Media Notification (Background Audio)**
When `backgroundPlayEnabled = true` and player is playing, show a persistent notification with:
- Content title + episode info
- Play/Pause, Previous episode, Next episode actions
- Seek bar in notification (Android 13+)

media_kit supports this via `AndroidNotificationSettings` in `PlayerConfiguration`:
```dart
_player = Player(
  configuration: PlayerConfiguration(
    title: widget.title,
    // media_kit handles Android MediaSession automatically
  ),
);
```
Also requires `audio_session` package for proper audio focus management:
- Pause when phone call comes in
- Resume when call ends
- Pause when headphones are unplugged (standard Android behavior)

---

**F. Headphone / Bluetooth Media Button Support**
Single button press → play/pause
Double press → next episode (if available)
Triple press → seek back 10s

Handled via `audio_session` package:
```dart
final session = await AudioSession.instance;
await session.configure(AudioSessionConfiguration.music());
session.becomingNoisyEventStream.listen((_) => _player.pause()); // headphone unplug
```
For button events, register a `MediaButtonReceiver` via platform channel or use `audio_service` package.

---

**G. Volume Boost Visual Indicator**
When MPV volume > 100% (i.e., `volumeBoost > 1.0`), the swipe volume gesture indicator shows:
- `🔊 150%` instead of just `75%`
- Small persistent badge `"🔊 +50%"` in top-right corner (next to network speed badge)
- Tapping this badge opens the volume boost slider in quick settings

---

**H. Long-Press Subtitle Text = Copy to Clipboard**
When a subtitle line is displayed, long-pressing it copies the text to clipboard and shows:
`"Copied to clipboard"` snackbar. Useful for looking up words.
```dart
GestureDetector(
  onLongPress: () {
    Clipboard.setData(ClipboardData(text: currentSubtitleText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 2)));
  },
  child: SubtitleText(...),
)
```

---

**I. Orientation Manual Cycle**
The rotate button in top bar cycles through:
`auto → force landscape-left → force landscape-right → auto`

```dart
void _cycleOrientation() {
  setState(() {
    switch (prefs.orientationMode) {
      case 'auto':
        prefs.orientationMode = 'landscape_left';
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
        break;
      case 'landscape_left':
        prefs.orientationMode = 'landscape_right';
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
        break;
      default:
        prefs.orientationMode = 'auto';
        SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    }
  });
}
```
Show current mode as badge next to rotate icon: `↺ Auto`, `↺ Left`, `↺ Right`.

---

**J. Share Timestamp**
Long-press the time display → share sheet:
`"Watching [Drama Title] - Episode 5 at 45:20 on RaddFlix"`
Uses `share_plus` package (already in `pubspec.yaml`).

---

## 4. PlayerSettingsScreen Layout

```
PlayerSettingsScreen
├── Gestures
│   ├── Master toggle, per-gesture enable/sensitivity
│   ├── Double-tap seconds, long-press speed
│   ├── Gesture zone width, Rage Skip
├── Controls
│   ├── Button size, opacity, auto-hide
│   ├── Show/hide each button (checkboxes)
│   └── Seek bar options
├── Subtitles
│   ├── Style (font/color/outline/position)
│   ├── Encoding override
│   └── Auto-detect (local files)
├── Audio
│   ├── Equalizer + Dialogue Boost
│   ├── Volume boost, normalization
│   └── Stereo/Mono + balance
├── Video
│   ├── Brightness / Contrast / Saturation / Hue
│   └── Night Mode, Sharpness
├── Track Settings
│   ├── Remember audio language
│   ├── Remember subtitle language
│   ├── Auto-select by device language
│   ├── Show active track badge
│   └── Show track count badge
├── New Features
│   ├── Ambilight (toggle + settings)
│   ├── Transparent Player (toggle + opacity)
│   ├── Binge Guard (toggle + threshold)
│   ├── Sleep Fade (toggle + duration)
│   └── Rage Skip (toggle + seconds)
├── Playback
│   ├── Speed + remember
│   ├── Resume position
│   ├── Auto-play next, countdown
│   ├── Seek-back on resume (0/3s/5s/10s)
│   ├── Long-press play = restart (toggle)
│   ├── Background audio
│   └── Hardware decoder
└── Appearance
    ├── Accent color, font scale
    ├── Orientation mode
    └── Info badges (network speed, decoder, volume boost)
```

---

## 5. Quick Settings Panel (In-Player)

```
┌─── Player Settings ──────────────────────────────┐
│  Gestures      [═══════● On]                     │
│  Subtitles     [═════●   On]   Style →           │
│  Sub Size      [────●────] 18px                  │
│  Sub Sync      -200ms           Reset ↺          │
│  Audio Sync    +0ms             Sync →           │
│  Speed         [0.75 / 1.0● / 1.25 / 1.5 / 2.0] │
│  Dialogue Boost[●         Off]                   │
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

| content_type | Show skip intro? |
|---|---|
| series / drama / anime / donghua / cartoon / show | ✅ Yes |
| movie / song / clip / short / documentary / music_video | ❌ No |
| Any type, duration < 10 min | ❌ No |

---

## 9. Implementation Priority

### Phase 3A — Foundation
1. `player_prefs.dart` + model
2. `player_prefs_provider.dart` (Riverpod StateNotifier)
3. Wire into `player_screen.dart`
4. Replace hardcoded gesture values with prefs

### Phase 3B — Controls & Settings UI
1. `player_settings_screen.dart`
2. Quick settings bottom sheet
3. Button show/hide + auto-hide timer
4. Seek bar options

### Phase 3C — Smart Skip Intro + Track Intelligence
1. `smart_intro_store.dart`
2. Add `content_type` param to PlayerScreen
3. Smart intro logic (series only, save per series)
4. Active track highlighted in `_TracksPanel` (add `activeIndex` param)
5. Active track badge in top bar (`🎵 Urdu`, `CC English`)
6. Track count badge (`3A · 2S`)
7. Track memory + auto-select by locale

### Phase 3D — Audio & Subtitle Sync Panel
1. `sync_panel.dart` (shared for both audio and sub)
2. ±50ms / ±100ms / ±500ms buttons + slider + Reset
3. Live delay badges in header that reset on tap
4. Wire to MPV `audio-delay` and `sub-delay`
5. Add Sync tab to audio panel and subtitle panel

### Phase 3E — Subtitle System
1. Subtitle timing offset (via sync panel)
2. Subtitle style panel
3. Encoding override picker
4. Auto-detect local files
5. Long-press subtitle text = copy to clipboard

### Phase 3F — Cinematic Mode
1. `cinematic_overlay.dart`
2. Lock button configurable behavior
3. Edge-swipe minimal strip

### Phase 3G — Audio & Video Enhancement
1. Audio delay (via sync panel)
2. Volume boost + boost indicator badge
3. 10-band EQ + Dialogue Boost
4. Video filters (brightness/contrast/saturation/hue/night mode/sharpness)
5. Audio normalization, stereo/mono, balance

### Phase 3H — Small Essential Features
1. Seek-back on app resume
2. Tap time = toggle elapsed/remaining
3. Tap time long-press = jump to timestamp
4. Long-press play = restart from beginning
5. Android media notification + audio focus (`audio_session`)
6. Headphone button support (play/pause, next, seek back)
7. Orientation cycle button (auto/left/right)
8. Share timestamp (long-press time)

### Phase 3I — New Original Features
1. Sleep Fade
2. Rage Skip
3. Scene Bookmarks
4. Ambilight Mode
5. Transparent Player
6. Binge Guard

### Phase 3J — Advanced
1. A-B Loop
2. Frame-by-frame
3. Chapter markers on seek bar
4. Screenshot to gallery

### Phase 4 (Future — not this agent)
- Button drag-to-reorder editor
- OpenSubtitles search (needs API key)
- Auto intro time detection (audio fingerprinting)

---

## 10. MPV Command Reference

```dart
// Equalizer
await player.setProperty('af', 'equalizer=f=60:...,equalizer=f=170:...');

// Volume boost
VolumeController.instance.maxVolume();
await player.setProperty('volume', '${(boost * 100).toInt()}');

// Video filters
await player.setProperty('vf', buildVfString(prefs));

// Audio delay
await player.setProperty('audio-delay', '${ms / 1000.0}');

// Subtitle delay
await player.setProperty('sub-delay', '${ms / 1000.0}');

// Hardware decoder
await player.setProperty('hwdec', enabled ? 'auto' : 'no');

// Playback speed
await player.setRate(speed);

// Frame step
await player.command(['frame-step']);
await player.command(['frame-back-step']);

// Screenshot
final Uint8List? frame = await player.screenshot();
```

---

## 11. Packages to Add to `pubspec.yaml`

```yaml
# Screenshot → save to gallery
gal: ^2.3.0

# Color picker (subtitle color, accent color)
flutter_colorpicker: ^1.1.0

# Audio focus management + headphone button + notification
audio_session: ^0.1.21
```

All other packages already in pubspec:
`media_kit`, `media_kit_video`, `shared_preferences`, `screen_brightness`,
`volume_controller`, `file_picker`, `video_thumbnail`, `sqflite`,
`path_provider`, `flutter_animate`, `share_plus`

---

## 12. Files to Modify in Existing Code

1. **`player_screen.dart`** — add `content_type` param, wire PlayerPrefs, add new widgets, fix lifecycle for seek-back on resume
2. **`player_screen.dart` `_TracksPanel`** — add `activeIndex` parameter, highlight selected track with checkmark + bold + accent color
3. **`player_screen.dart` `_buildAudioLabels`** — already works, no changes needed
4. **`player_screen.dart` `didChangeAppLifecycleState`** — add seek-back on resume
5. **`player_screen.dart` time label** — add tap handler for elapsed/remaining toggle
6. **`player_screen.dart` skip intro** — replace hardcoded 85s with SmartIntroStore
7. **`app.dart`** — add route for `PlayerSettingsScreen`
8. **`pubspec.yaml`** — add `gal`, `flutter_colorpicker`, `audio_session`

---

## 13. Testing Checklist

- [ ] All existing gestures still work after refactor
- [ ] PlayerPrefs loads from SharedPrefs on cold start, persists across sessions
- [ ] Gesture sensitivity changes take effect immediately
- [ ] Skip intro shows for drama/anime, does NOT show for movies and songs
- [ ] Skip intro does NOT show if video < 10 minutes
- [ ] Skip intro time saved per series — next episode auto-shows at same time
- [ ] Audio track panel shows active track highlighted with checkmark
- [ ] Subtitle track panel shows active track highlighted
- [ ] Active track badges visible in top bar ("🎵 Urdu", "CC English")
- [ ] Track count badge shows correctly (e.g., "3A · 2S")
- [ ] Track memory: select Urdu audio, close player, reopen — Urdu auto-selected
- [ ] Audio sync: ±50ms buttons work in real time, Reset clears to 0
- [ ] Subtitle sync: same
- [ ] Audio delay badge shows in header when non-zero, tap to reset
- [ ] Sub delay badge shows in header when non-zero, tap to reset
- [ ] Seek-back on resume: leave app for 5s, return, player seeks back 5s
- [ ] Tap time label = toggles elapsed/remaining
- [ ] Long-press subtitle line = copies text to clipboard
- [ ] Volume boost badge shows "🔊 150%" when above 100%
- [ ] Cinematic mode: controls hidden, gestures work, tap = pause/resume
- [ ] Lock mode: unchanged from before
- [ ] Transparent mode: video opacity changes with slider
- [ ] Ambilight: glow color matches video edges
- [ ] Rage Skip: triple-tap → animation + correct skip distance
- [ ] Sleep Fade: volume fades before timer ends
- [ ] Scene Bookmark: long-press seek bar → dot appears → panel shows bookmark
- [ ] Binge Guard: fires at correct time (test with low threshold)
- [ ] Orientation cycle: button cycles auto → left → right → auto
- [ ] Media notification: shows when playing in background with play/pause controls
- [ ] Settings screen: all toggles persist after app restart
- [ ] `flutter analyze` — zero errors
