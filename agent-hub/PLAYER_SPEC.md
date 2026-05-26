# RaddFlix Player — Supreme Customizable Player Specification
> **Task for next agent:** Implement everything in this document into `player_screen.dart` and related files.
> **Research basis:** MX Player, VLC, nPlayer, Infuse, KMPlayer, BSPlayer, Kodi, PowerDVD, Nova, Just Player, mpv, Vimu, PlayerXtreme, Plex, Jellyfin, Potplayer
> **Last updated:** 2026-05-26 Session 5
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
- ✅ Skip intro button (fixed at 85s — needs to be dynamic)
- ✅ Next episode countdown overlay
- ✅ PiP via MethodChannel
- ✅ Chromecast via MethodChannel
- ✅ Buffering indicator
- ✅ Seek scrub label with position preview
- ✅ Drag indicator for brightness/volume

Build ON TOP of these. Do not remove them.

---

## 1. Architecture — New Files to Create

```
raddflix_flutter/lib/
├── screens/
│   ├── player_screen.dart              ← existing, expand this
│   └── player_settings_screen.dart     ← NEW: full player customization UI
├── core/
│   ├── player/
│   │   ├── player_prefs.dart           ← NEW: all player preferences model + SharedPrefs persistence
│   │   ├── player_prefs_provider.dart  ← NEW: Riverpod StateNotifier for player prefs
│   │   ├── subtitle_service.dart       ← NEW: auto-detect + parse + style subtitles
│   │   ├── ab_loop_controller.dart     ← NEW: A-B loop logic
│   │   ├── equalizer_controller.dart   ← NEW: EQ state + media_kit EQ integration
│   │   └── player_button_layout.dart   ← NEW: customizable button position model
│   └── services/
│       └── subtitle_search_service.dart ← NEW: OpenSubtitles API integration
├── widgets/player/
│   ├── player_gesture_layer.dart       ← NEW: extracted, configurable gesture zones
│   ├── cinematic_overlay.dart          ← NEW: cinematic mode layer
│   ├── subtitle_overlay.dart           ← NEW: styled subtitle rendering
│   ├── seek_thumbnail.dart             ← NEW: thumbnail preview on seek
│   ├── eq_panel.dart                   ← NEW: 10-band equalizer widget
│   ├── ab_loop_panel.dart              ← NEW: A-B loop control widget
│   ├── video_enhance_panel.dart        ← NEW: brightness/contrast/saturation/hue
│   ├── player_button_editor.dart       ← NEW: drag-to-rearrange button layout editor
│   └── player_controls_bar.dart        ← NEW: bottom control bar (customizable)
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
  bool longPressSpeedEnabled;    // long-press for 2× speed (default: true)
  double longPressSpeed;         // 1.5/2.0/2.5/3.0 (default: 2.0)
  bool pinchZoomEnabled;         // pinch to zoom (default: true)
  double swipeSensitivity;       // 0.5 – 2.0 (default: 1.0)
  double seekSensitivity;        // 0.5 – 2.0 (default: 1.0)
  double gestureZoneWidth;       // % of screen for left/right zones (default: 0.4 = 40%)

  // ── CONTROL BAR SETTINGS ─────────────────────────────────────
  List<String> topBarButtons;    // ordered list of visible top-bar button IDs
  List<String> bottomBarButtons; // ordered list of visible bottom-bar button IDs
  double buttonSize;             // 0.8 – 1.4 scale (default: 1.0)
  double controlBarOpacity;      // 0.3 – 1.0 (default: 0.85)
  int autoHideSeconds;           // 2/3/5/10/0=never (default: 3)
  bool showSeekBar;              // show/hide seek bar (default: true)
  bool showTimeElapsed;          // show elapsed time (default: true)
  bool showTimeRemaining;        // show remaining time (default: false)
  bool showChapterMarkers;       // show chapter markers on seek bar (default: true)
  bool showThumbnailPreview;     // thumbnail preview while scrubbing (default: true)
  bool showBufferBar;            // show buffered amount on seek bar (default: true)
  bool compactTopBar;            // single-row top bar vs expanded (default: false)
  String seekBarThumbStyle;      // 'dot' / 'line' / 'circle' (default: 'circle')
  String controlsPosition;       // 'bottom' / 'sides' (future, default: 'bottom')

  // ── AVAILABLE BUTTON IDs (can be enabled/disabled/repositioned) ──
  // Top bar: 'back' 'title' 'audio' 'subtitle' 'ratio' 'speed'
  //          'pip' 'cast' 'sleep' 'rotate' 'screenshot' 'more'
  // Bottom bar: 'seek_back' 'play_pause' 'seek_forward' 'next_ep'
  //             'lock' 'seek_bar' 'time' 'ab_loop' 'boost_volume' 'eq'

  // ── SUBTITLE SETTINGS ────────────────────────────────────────
  bool subtitleAutoDetect;       // auto-detect .srt/.ass in same folder (default: true)
  String subtitleEncoding;       // 'utf-8' / 'latin1' / 'windows-1252' / 'auto' (default: 'auto')
  double subtitleFontSize;       // 10 – 40 (default: 18)
  String subtitleFontFamily;     // 'Sans-Serif' / 'Serif' / 'Monospace' / 'system' (default: 'Sans-Serif')
  bool subtitleBold;             // (default: false)
  bool subtitleItalic;           // (default: false)
  Color subtitleTextColor;       // (default: Colors.white)
  Color subtitleOutlineColor;    // (default: Colors.black)
  double subtitleOutlineThickness; // 0 – 4 (default: 2.0)
  Color subtitleBackgroundColor; // (default: Colors.transparent)
  double subtitleBackgroundOpacity; // 0 – 1 (default: 0.0)
  String subtitlePosition;       // 'bottom' / 'top' / 'center' (default: 'bottom')
  double subtitleVerticalOffset; // % from edge (default: 0.1 = 10%)
  int subtitleTimingOffsetMs;    // -5000 – +5000 ms (default: 0)
  bool subtitleEnabled;          // global on/off (default: true)

  // ── AUDIO SETTINGS ───────────────────────────────────────────
  int audioTimingOffsetMs;       // -5000 – +5000 ms (default: 0)
  double volumeBoost;            // 1.0 – 3.0 (100% – 300%) (default: 1.0)
  bool equalizerEnabled;         // (default: false)
  String equalizerPreset;        // 'flat'/'rock'/'pop'/'bass'/'movie'/'custom' (default: 'flat')
  List<double> equalizerBands;   // 10 values: -12.0 to +12.0 dB (default: all 0.0)
  bool audioNormalization;       // (default: false)
  bool stereoMono;               // false=stereo, true=mono (default: false)
  double audioBalance;           // -1.0 (left) to 1.0 (right) (default: 0.0)

  // ── VIDEO ENHANCEMENT ────────────────────────────────────────
  double brightness;             // -0.5 – +0.5 (default: 0.0 = system)
  double contrast;               // -0.5 – +0.5 (default: 0.0)
  double saturation;             // -0.5 – +0.5 (default: 0.0)
  double hue;                    // -180 – +180 degrees (default: 0.0)
  bool nightMode;                // warm tint overlay (default: false)
  double nightModeIntensity;     // 0.1 – 1.0 (default: 0.5)
  bool sharpnessEnabled;         // (default: false)
  double sharpness;              // 0.0 – 1.0 (default: 0.3)

  // ── PLAYBACK SETTINGS ────────────────────────────────────────
  double playbackSpeed;          // 0.25/0.5/0.75/1.0/1.25/1.5/1.75/2.0/2.5/3.0/4.0 (default: 1.0)
  bool rememberSpeed;            // persist speed across sessions (default: false)
  bool rememberPosition;         // resume from last position (default: true)
  bool autoPlayNext;             // auto-play next episode (default: true)
  int nextEpisodeCountdown;      // 5/10/15 seconds (default: 10)
  bool skipSilence;              // auto-skip quiet sections (default: false)
  double skipSilenceThreshold;   // volume level that counts as silence 0.01-0.1 (default: 0.03)
  bool hwDecoderEnabled;         // hardware decoding (default: true)
  bool backgroundPlayEnabled;    // audio continues in background (default: false)
  bool preventScreenOff;         // keep screen on during playback (default: true)
  bool autoRotate;               // auto-rotate based on video aspect (default: true)

  // ── MODES ────────────────────────────────────────────────────
  bool cinematicModeOnLock;      // lock button activates cinematic mode (default: false)
  bool gesturesInCinematic;      // gestures still work in cinematic (default: true)
  String cinematicTapBehavior;   // 'pause_resume' / 'show_controls' (default: 'pause_resume')

  // ── UI APPEARANCE ─────────────────────────────────────────────
  String accentColor;            // hex color for seek bar + icons (default: '#E8002D')
  double uiFontSize;             // 0.8 – 1.2 scale for UI labels (default: 1.0)
  bool showEpisodeInfo;          // episode number in header (default: true)
  bool showNetworkSpeed;         // show KB/s for streams (default: false)
  bool showDecoderInfo;          // HW/SW badge (default: false)
  bool vibrateOnGesture;         // haptic on double-tap (default: true)

  // ── QUICK TOGGLES (shown in player ≥ controls) ───────────────
  // These are master toggles user can flip from the player settings button
  // (accessible via the 'more' button or a gear icon in top bar)
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

**Gestures:**
| Gesture | Action | Configurable |
|---|---|---|
| Swipe up/down left zone | Brightness ±% | ✅ disable, sensitivity |
| Swipe up/down right zone | Volume ±% | ✅ disable, sensitivity |
| Swipe horizontal anywhere | Seek ±seconds | ✅ disable, sensitivity |
| Double-tap left zone | Seek back N seconds | ✅ N = 5/10/15/20/30 |
| Double-tap right zone | Seek forward N seconds | ✅ N = 5/10/15/20/30 |
| Double-tap center | Play/Pause | ✅ enable/disable |
| Single tap center | Show/hide controls | ✅ always |
| Long-press | 2× speed (hold) | ✅ disable, speed value |
| Pinch | Zoom in/out | ✅ disable |
| Two-finger swipe up/down | Zoom discrete | ✅ |
| Swipe from left edge | Chapter prev | ✅ enable/disable |
| Swipe from right edge | Chapter next | ✅ enable/disable |

**Visual feedback:**
- Brightness/volume: centered pill with icon + bar + % value
- Seek: centered pill with `MM:SS (±Ns)` and left/right arrow animation
- Zoom: top-center badge showing `1.2×`
- Double-tap: ripple animation + seek flash overlay

---

### 3.2 Cinematic Mode

**What it is:** Complete UI blackout — zero chrome, zero distractions. Inspired by Infuse's cinematic mode and Kodi's full-screen mode.

**Behavior:**
- All controls hidden (seek bar, buttons, title, time — everything)
- Screen stays on (wakelock)
- Single tap: either pause/resume OR show controls (user-configurable)
- Gestures still work (brightness, volume, seek)
- **Lock button single-tap** → enters cinematic mode (configurable)
- While in cinematic: swipe from any edge shows a minimal unlock strip
- Unlock strip: just lock icon + play/pause icon, auto-hides in 2s
- Exit cinematic: tap unlock strip lock icon, or press Android back
- **Visual:** Fade-to-black animation (300ms) when entering

**Cinematic mode indicator:**
- When entering: brief "Cinematic Mode" text fades in/out over center
- Sleep timer badge still shows (top-right, very subtle)

---

### 3.3 Subtitle System

**Auto-detection (like MX Player):**
1. On file open, extract video file path/name (strip extension)
2. Search same directory for: `filename.srt`, `filename.en.srt`, `filename.ass`, `filename.ssa`, `filename.vtt`, `filename.sub`, `filename.smi`, `filename.ttml`
3. Also search for any `.srt`/`.ass` files in same folder
4. Show detected files in subtitle track list under "External" section
5. Auto-load if only one found and `subtitleAutoDetect` is true
6. For network streams: check if server provides subtitle URL alongside video URL

**Supported formats:** SRT, ASS, SSA, VTT, SUB, SMI, TTML, LRC, XML/TTML  
(media_kit handles embedded MKV subs; external files need parsing)

**Subtitle styling panel** (accessible from subtitle button long-press or settings):
```
┌─── Subtitle Style ─────────────────────────────┐
│ Font Size        [──●────────] 18px             │
│ Font Family      [Sans-Serif ▼]                 │
│ Bold [✓]  Italic [ ]                            │
│                                                 │
│ Text Color       [████ White  ▼]                │
│ Outline Color    [████ Black  ▼]                │
│ Outline Thickness [──●────] 2px                 │
│                                                 │
│ Background       [████ None   ▼]                │
│ Background Opacity [────●───] 0%                │
│                                                 │
│ Position         [Bottom ●] [Top] [Center]      │
│ Vertical Offset  [────●────] 10%                │
│                                                 │
│ Timing Offset    [-500ms ──●── +500ms]          │
│                  Current: +0ms                  │
│                                                 │
│ Encoding         [Auto-detect ▼]                │
│                                                 │
│         [Reset to defaults]  [Done]             │
└─────────────────────────────────────────────────┘
```

**Subtitle timing adjustment:** Also accessible via a quick ± button while subs are active (show +500ms / -500ms quick buttons in controls)

**Online subtitle search (Phase 2 — optional):**
- Via OpenSubtitles API (free tier)
- Search by movie/show name + language
- Download and apply directly

---

### 3.4 Audio System

**Audio delay panel:**
```
Audio Sync: [-5000ms ──●── +5000ms]
            Current: +0ms
[−500ms]  [−100ms]  [−50ms]  [+50ms]  [+100ms]  [+500ms]
```

**10-Band Equalizer:**
```
┌─── Equalizer ───────────────────────────────────────┐
│ [✓ Enabled]    Preset: [Rock ▼]                     │
│                                                     │
│ +12dB  ┤   │   │   │   │   │   │   │   │   │       │
│  +6dB  ┤   █   │   │   │   │   │   │   │   │       │
│   0dB  ┼───────────────────────────────────────     │
│  -6dB  ┤   │   │   │   │   │   │   │   █   │       │
│ -12dB  ┤   │   │   │   │   │   │   │   │   │       │
│       60 170 310 600  1K  3K  6K 12K 14K 16K Hz    │
│                                                     │
│ Presets: [Flat][Rock][Pop][Bass][Movie][Treble]     │
│          [Classical][Jazz][Custom]                   │
│                                                     │
│ Bass Boost: [──●────] 0dB                           │
│ Audio Norm: [ ] Normalize volume                    │
│ Volume Boost: [──●────] 100%  (up to 300%)         │
│ Balance:    L [────●────] R                         │
│                                                     │
│              [Reset]        [Done]                  │
└─────────────────────────────────────────────────────┘
```
Note: media_kit supports setting EQ via MPV's `af` (audio filter) command: `player.setProperty('af', 'equalizer=f=60:width_type=o:width=2:g=6.0,...')`

**Presets (dB values per band: 60/170/310/600/1K/3K/6K/12K/14K/16K Hz):**
- Flat: [0,0,0,0,0,0,0,0,0,0]
- Rock: [+5,+3,0,0,-2,+3,+5,+5,+4,+3]
- Pop: [0,0,+2,+4,+4,+2,0,-1,-1,0]
- Bass Boost: [+8,+7,+5,+3,0,0,0,0,0,0]
- Movie/Cinema: [+3,+2,0,0,0,+2,+3,+3,+2,+1]
- Classical: [0,0,0,0,0,0,-3,-4,-4,-5]
- Jazz: [+3,+2,0,+3,+4,+3,+1,+2,+3,+2]
- Treble: [0,0,0,0,0,+3,+5,+6,+6,+7]

---

### 3.5 Video Enhancement

Panel (accessible from long-press on fit/ratio button, or from settings):
```
┌─── Picture ──────────────────────────────────────┐
│ Brightness  [-50% ──●── +50%]  Current: 0%       │
│ Contrast    [-50% ──●── +50%]  Current: 0%       │
│ Saturation  [-50% ──●── +50%]  Current: 0%       │
│ Hue         [-180° ──●── +180°] Current: 0°      │
│ Sharpness   [Off ──────●──] 30%                  │
│                                                  │
│ Night Mode  [✓]  Intensity [────●────] 50%       │
│ (adds warm amber tint for dark-room viewing)     │
│                                                  │
│              [Reset All]    [Done]               │
└──────────────────────────────────────────────────┘
```
Implementation: media_kit/mpv supports `vf` (video filter):
- Brightness/Contrast/Saturation/Hue: `eq=brightness=X:contrast=Y:saturation=Z:gamma=1`
- Night mode: `colorchannelmixer=0.9:0.1:0.05:0:0.01:0.8:0.05:0:0:0:0.7:0` (amber tint)
- Sharpness: `unsharp=lx=3:ly=3:la=X`

---

### 3.6 A-B Loop

**What it is:** User sets a start point (A) and end point (B). Player loops that section forever.  
Used for: language learning, studying scenes, repeating a song section.

**UI:**
- A-B Loop button in bottom bar (can be hidden via customization)
- First tap: sets A point → button shows "[A] →" with A timestamp
- Second tap: sets B point → button shows "[A→B]" looping badge, loop begins
- Third tap: clears both → "A-B" icon resets

**Visual while looping:**
- Seek bar shows a colored region between A and B markers
- Loop icon badge visible in top bar (replaces nothing, just appears)
- When playback hits B, instantly seeks to A

---

### 3.7 Speed Control (Enhanced)

**Available speeds:** 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0  
**Custom speed:** Slider from 0.25 to 4.0 in 0.05 increments  
**Quick access:** Long-press speed button for direct slider  
**Remember speed:** Option to persist speed per title or globally

**Speed indicator:**
- When speed ≠ 1×: small badge on seek bar area showing current speed  
- During long-press fast: "2.0× Speed" badge at top center

---

### 3.8 Frame-by-Frame

- Previous frame: available via `player.state.position - Duration(milliseconds: 42)` (approx 1/24fps)
- Next frame: accessible via MPV `frame-step` command: `player.setProperty('pause', 'yes')` then `player.command(['frame-step'])`
- Surface: two small buttons (‹ ›) appear when playback is paused and user long-presses the pause button
- Auto-hide when play resumes

---

### 3.9 Chapter Support

- media_kit exposes `player.state.tracks` — check for chapter data
- Chapters displayed as tick marks on seek bar
- Long-press seek bar → chapter list popup
- Swipe from screen edges (configurable) → prev/next chapter
- Chapter name shown briefly in top-center when seeking between chapters

---

### 3.10 Skip Silence

- media_kit/mpv: `player.setProperty('af', 'silencedetect=n=-30dB:d=0.5')`  
  (Listen for `silence_start`/`silence_end` log events, seek forward)
- Toggle from player settings or quick toggle
- Visual: "Skipped Xs of silence" toast when triggered
- Threshold configurable (very quiet vs moderate silence)

---

### 3.11 Screenshot

- `player.screenshot()` — returns `Uint8List?`
- Save to device gallery: use `image_gallery_saver` or `gal` package
- Button: available in top bar (optional, can be hidden)
- Toast: "Screenshot saved" with thumbnail preview

---

### 3.12 Seek Thumbnail Preview

**What it is:** As user drags the seek bar, a small thumbnail image appears above the thumb showing the frame at that position. Like YouTube or MX Player.

**Implementation:**
- `video_thumbnail` package: `VideoThumbnail.thumbnailData(video: path, timeMs: ms, quality: 50, maxWidth: 120)`
- Generate thumbnail on seek bar drag start, update every 500ms during drag
- Cache up to 20 thumbnails in memory
- Show above seek bar thumb: rounded `Image` widget 120×68px
- Only works for local files and cached streams (not live streams)

---

### 3.13 Playback History & Resume

- On player open: check `watch_positions` SQLite table for last position
- If position > 5% and < 90%: show resume prompt — "Resume from 23:45?" [Resume] [Start Over]
- Auto-save position every 5 seconds during playback
- On player close: save final position immediately
- Clear position when video reaches > 90% watched (mark as complete)

---

## 4. Button Customization System

### 4.1 Button IDs and Defaults

**Top bar (left to right):**
```
DEFAULT: [back] [title...........] [audio] [subtitle] [ratio] [speed] [sleep] [more]
OPTIONAL: screenshot, rotate-lock, decoder-info, cast, pip (moved from default)
```

**Bottom bar (left to right):**
```
DEFAULT: [lock] [seek_back] [play_pause] [seek_forward] [next_ep] [ab_loop] [time]
OPTIONAL: eq, boost_volume, screenshot, pip, cast
```

**Seek bar area (always shown if `showSeekBar: true`):**
```
[time_elapsed] [────────●────────] [time_remaining]
```

### 4.2 Button Layout Editor UI

Accessible via: Settings → Player → Customize Controls

```
┌── Customize Controls ──────────────────────────────┐
│                                                    │
│  TOP BAR PREVIEW:                                  │
│  ┌──────────────────────────────────────────────┐  │
│  │ ← │          Title         │ 🔊│📝│▣│⚡│ ⋮ │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  BOTTOM BAR PREVIEW:                               │
│  ┌──────────────────────────────────────────────┐  │
│  │ 🔒│ ⟪15│  ▶  │15⟫│ ⏭│[A-B]│  00:23/45:00  │  │
│  └──────────────────────────────────────────────┘  │
│                                                    │
│  AVAILABLE BUTTONS (drag to bars above):           │
│  [ Screenshot ] [ EQ ] [ PiP ] [ Cast ] [ Boost ] │
│  [ Decoder ]  [ Rotate ]  [ Chapters ]             │
│                                                    │
│  Button Size:    S [●──] M [─●─] L [──●]           │
│  Bar Opacity:    [────●────] 85%                   │
│  Auto-hide:      [3s ●] 5s / 10s / Never           │
│                                                    │
│          [Reset to defaults]  [Done ✓]             │
└────────────────────────────────────────────────────┘
```

Implementation note: Use `ReorderableListView` for drag-to-reorder. Store button order as `List<String>` in `PlayerPrefs`. Render buttons in order. If button not in list → hidden.

---

## 5. Player Settings Screen (`player_settings_screen.dart`)

Full settings screen — accessed via gear icon in player top bar (or from app Settings > Player).

```
Player Settings
├── Gestures
│   ├── Enable gestures (master toggle)
│   ├── Swipe for brightness (on/off)
│   ├── Swipe for volume (on/off)
│   ├── Swipe to seek (on/off)
│   ├── Double-tap seek seconds (5/10/15/20/30)
│   ├── Long-press speed (1.5×/2×/2.5×/3×)
│   ├── Swipe sensitivity (slider)
│   └── Seek sensitivity (slider)
│
├── Controls
│   ├── Customize controls (→ button layout editor)
│   ├── Button size (S/M/L)
│   ├── Control bar opacity (slider)
│   ├── Auto-hide timer (2s/3s/5s/10s/Never)
│   ├── Show seek bar (on/off)
│   ├── Show elapsed time (on/off)
│   ├── Show remaining time (on/off)
│   ├── Show chapter markers (on/off)
│   └── Seek thumbnail preview (on/off)
│
├── Subtitles
│   ├── Auto-detect subtitle files (on/off)
│   ├── Style → (→ subtitle style panel)
│   ├── Default encoding (Auto/UTF-8/Latin/Windows-1252)
│   └── Default timing offset (slider)
│
├── Audio
│   ├── Audio delay (slider, persists across sessions)
│   ├── Volume boost (slider 100%-300%)
│   ├── Equalizer → (→ EQ panel)
│   ├── Audio normalization (on/off)
│   ├── Stereo/Mono (toggle)
│   └── Audio balance (L-R slider)
│
├── Picture
│   ├── Picture settings → (→ video enhance panel)
│   └── Night mode (quick toggle + intensity slider)
│
├── Playback
│   ├── Remember playback speed (on/off)
│   ├── Resume from last position (on/off)
│   ├── Auto-play next episode (on/off)
│   ├── Next episode countdown (5s/10s/15s)
│   ├── Skip silence (on/off + threshold slider)
│   ├── Hardware decoder (on/off)
│   ├── Background play (on/off)
│   └── Keep screen on (on/off)
│
├── Cinematic Mode
│   ├── Lock button → cinematic mode (on/off)
│   ├── Gestures in cinematic (on/off)
│   └── Tap in cinematic: pause/resume OR show controls (choice)
│
├── Appearance
│   ├── Accent color (color picker — 8 presets + custom hex)
│   ├── UI font size (slider 0.8×–1.2×)
│   ├── Show episode info in header (on/off)
│   ├── Show network speed (on/off)
│   ├── Haptic feedback (on/off)
│   └── Seek bar thumb style (dot/line/circle)
│
└── Reset All Settings
```

---

## 6. Supported Formats

media_kit uses libmpv under the hood. It supports virtually everything. Document this for users:

**Video containers:** MKV, MP4, AVI, MOV, WMV, FLV, 3GP, WebM, TS, M2TS, MPEG, OGV, M4V, RMVB, ASF, VOB, DIVX
**Video codecs:** H.264, H.265/HEVC, VP8, VP9, AV1, MPEG-4, MPEG-2, Xvid, DivX, RMVB, WMV  
**Audio codecs:** AAC, MP3, AC3/Dolby Digital, DTS, EAC3/Dolby Digital Plus, Opus, Vorbis, FLAC, PCM, TrueHD  
**Subtitle formats (embedded):** SRT, ASS/SSA, VTT, SUBRIP, PGS (image), VobSub  
**Subtitle formats (external):** SRT, ASS, SSA, VTT, SUB, SMI, TTML, LRC  
**Streaming protocols:** HTTP, HTTPS, HLS (m3u8), DASH, RTMP, RTSP, MMS

---

## 7. Modes Summary Table

| Mode | How to enter | What's hidden | Gestures | Controls |
|---|---|---|---|---|
| **Normal** | Default | Nothing | All | Full |
| **Cinematic** | Lock btn (configurable) | Everything | ✅ Still work | Single swipe shows strip |
| **Locked** | Lock button (default) | All except lock btn | ✅ Still work | Just unlock button |
| **Background** | Home button | Screen off | Volume | Audio only |
| **PiP** | PiP button | Full screen | None | Mini controls |
| **Cast** | Cast button | Device screen | Volume | Cast mini bar |

---

## 8. UI Design Guidelines

**Style:** AMOLED black (#000000 base), RaddFlix red (#E8002D) accent. Match existing app design system (AppColors, AppRadius, AppDurations, AppCurves from constants.dart).

**Control bar background:** Gradient from black (full opacity) at edges → transparent in center for the top bar. Solid black-with-opacity for bottom bar.

**Animations:**
- Controls show: 200ms fadeIn + slideY(bottom 0.1→0)
- Controls hide: 300ms fadeOut
- Panels (speed/eq/etc.): slideX from right (200ms, AppCurves.standard)
- Mode transitions: 300ms fade

**Typography:**
- Time display: `Roboto Mono` or system monospace — prevents layout shift as time changes
- All other text: app font system

**Touch targets:** Minimum 44×44dp for all tappable elements. Control bar icons: 22–28dp icon inside 44dp touch area.

**Seek bar:**
- Height: 3dp normal, 5dp while dragging
- Thumb: 12dp circle, expands to 16dp when dragging
- Buffered: white at 25% opacity
- Played: accent color (#E8002D)
- A-B region: accent color at 40% opacity fill

---

## 9. Implementation Priority Order

The next agent should implement in this order:

### Phase 3A — Gesture Enhancements (lowest effort, highest impact)
1. Make double-tap seek seconds configurable (currently hardcoded 15s)
2. Add gesture sensitivity settings
3. Configurable long-press speed value
4. Save gesture prefs to SharedPreferences via `player_prefs.dart`

### Phase 3B — Controls Customization (medium effort, very visible)
1. Create `PlayerPrefs` model + `PlayerPrefsProvider`
2. Create `PlayerSettingsScreen` (flat list, all toggles)
3. Button show/hide (no drag yet — just enable/disable checkboxes)
4. Auto-hide timer setting
5. Seek bar options (show/hide, elapsed/remaining)

### Phase 3C — Subtitle System (high impact for Pakistani drama audience)
1. Auto-detect subtitle files from same folder
2. Subtitle timing offset (±ms) slider in subtitle panel
3. Subtitle font size + color in subtitle style panel
4. External subtitle file picker (already exists — enhance UI)

### Phase 3D — Cinematic Mode (killer feature, medium effort)
1. Cinematic mode overlay widget
2. Lock button behavior (configurable: cinematic vs just-lock)
3. Gesture-still-works logic in cinematic
4. Edge-swipe to show minimal strip

### Phase 3E — Audio System (medium effort)
1. Audio delay offset slider
2. Volume boost (MPV `volume` property above 100)
3. 10-band EQ widget + presets
4. Audio normalization toggle

### Phase 3F — Advanced Features (high effort, Phase 4+)
1. A-B Loop
2. Skip silence
3. Frame-by-frame
4. Chapter markers on seek bar
5. Seek thumbnail preview
6. Video enhancement (brightness/contrast/saturation/hue/night mode)
7. Button layout drag editor
8. Screenshot

---

## 10. Implementation Notes & Gotchas

### media_kit / MPV specific commands
```dart
// Set MPV property
await player.setProperty('key', 'value');

// Run MPV command
await player.command(['command', 'arg1', 'arg2']);

// Equalizer (audio filter)
// Format: f=FREQ:width_type=o:width=2:g=GAIN
await player.setProperty('af', 
  'equalizer=f=60:width_type=o:width=2:g=5.0,'
  'equalizer=f=170:width_type=o:width=2:g=3.0,'
  // ... all 10 bands
);

// Volume boost above 100% (MPV supports up to 1000)
await player.setProperty('volume', '150'); // 150%

// Video filters (brightness/contrast/saturation/hue)
await player.setProperty('vf', 'eq=brightness=0.1:contrast=1.1:saturation=1.2:gamma=1.0');

// Night mode (warm amber tint via color channel mixer)
await player.setProperty('vf', 
  'colorchannelmixer=rr=0.9:rg=0.1:rb=0.05:'
  'gr=0.01:gg=0.8:gb=0.05:'
  'br=0:bg=0:bb=0.7');

// Audio delay (milliseconds)
await player.setProperty('audio-delay', '0.5'); // +500ms

// Hardware decoder
await player.setProperty('hwdec', hwEnabled ? 'auto' : 'no');

// Playback speed  
await player.setRate(speed);

// Frame step
await player.command(['frame-step']);    // next frame
await player.command(['frame-back-step']); // prev frame

// Screenshot
final screenshot = await player.screenshot(); // returns Uint8List?
```

### Subtitle auto-detection
```dart
// Extract base path from video URL/path
String basePath = videoPath.replaceAll(RegExp(r'\.[^.]+$'), '');
String dir = path.dirname(videoPath);

// Check for subtitle files
final extensions = ['.srt', '.ass', '.ssa', '.vtt', '.sub', '.smi'];
for (final ext in extensions) {
  final file = File('$basePath$ext');
  if (await file.exists()) {
    // Add to subtitle tracks list
  }
}

// Also scan directory
final dir = Directory(path.dirname(videoPath));
final files = await dir.list().where((f) => 
  extensions.any((ext) => f.path.endsWith(ext))).toList();
```

### Volume boost + system volume
```dart
// Current VolumeController controls system volume (0.0–1.0)
// For boost beyond 100%, use MPV volume property instead
// MPV volume 100 = system volume 100%, MPV volume 150 = +50% software amplification
// Combine: system at max, MPV at boost level
VolumeController.instance.maxVolume();
await player.setProperty('volume', '${(boostLevel * 100).toInt()}');
```

### SharedPrefs persistence pattern
```dart
// In PlayerPrefsProvider (Riverpod StateNotifier)
class PlayerPrefsNotifier extends StateNotifier<PlayerPrefs> {
  static const _prefix = 'player_';
  
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    state = PlayerPrefs(
      doubleTapSeekSeconds: prefs.getInt('${_prefix}dbl_tap_seek') ?? 10,
      // ...
    );
  }
  
  Future<void> save(PlayerPrefs newPrefs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('${_prefix}dbl_tap_seek', newPrefs.doubleTapSeekSeconds);
    // ...
    state = newPrefs;
  }
}
```

---

## 11. Packages to Add

Add to `pubspec.yaml`:
```yaml
# Screenshot save to gallery
gal: ^2.3.0

# Color picker for subtitle/accent color settings
flutter_colorpicker: ^1.1.0
```

All other packages needed (media_kit, file_picker, shared_preferences, screen_brightness, volume_controller) are already in pubspec.yaml.

---

## 12. Quick Customization Access (In-Player)

From the player, the ⚙ (settings) button in top bar opens a **quick panel** (bottom sheet, not full screen) with the most common toggles:

```
┌─── Player Settings ──────────────────────────────┐
│  Gestures      [═══════● On]                     │
│  Subtitles     [═════●   On]   Style →           │
│  Sub Size      [────●────] 18px                  │
│  Speed         [0.75 / 1.0● / 1.25 / 1.5 / 2.0] │
│  Night Mode    [●         Off]                   │
│  Volume Boost  [──●──────] 100%                  │
│  Auto-Hide     [3s ●] 5s / 10s                   │
│  Cinematic     [●         Off]                   │
│                                                  │
│  [ Full Settings →]          [Done]              │
└──────────────────────────────────────────────────┘
```

"Full Settings →" opens `PlayerSettingsScreen` as a full page.

---

## 13. Files to Modify in Existing Code

1. **`player_screen.dart`** — read `PlayerPrefs` at build time, pass prefs to gesture handler and controls overlay. Use `ref.watch(playerPrefsProvider)` at the top.
2. **`player_screen.dart` `_GestureLayer`** — replace hardcoded `15` with `prefs.doubleTapSeekSeconds`, replace hardcoded `2.0` speed with `prefs.longPressSpeed`.
3. **`player_screen.dart` lock button handler** — check `prefs.cinematicModeOnLock`, enter cinematic vs just-lock.
4. **`app.dart` routes** — add route for `PlayerSettingsScreen`: `'/player-settings': (_) => const PlayerSettingsScreen()`
5. **`pubspec.yaml`** — add `gal` and `flutter_colorpicker`

---

## 14. Testing Checklist (agent must verify before pushing)

- [ ] All existing gestures still work after refactor
- [ ] PlayerPrefs loads from SharedPrefs on cold start
- [ ] Changing double-tap seconds in settings takes effect immediately in player
- [ ] Subtitle auto-detect finds .srt file in same folder as local video
- [ ] Subtitle timing offset slider shows change immediately
- [ ] Cinematic mode: controls completely hidden, single tap pause/resumes
- [ ] Cinematic mode: swipe brightness/volume still works
- [ ] Cinematic mode: swipe from edge shows minimal strip, auto-hides
- [ ] Lock mode: still works as before (backward compatible)
- [ ] Speed options all work (0.25×–4.0×)
- [ ] Settings screen: all toggles save and persist across player open/close
- [ ] Build passes: `flutter analyze` shows no errors
