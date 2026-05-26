# ZENO — Complete Brand Guidelines
**Version 1.0 | May 2026**
**Tagline:** Sab Dekho, Dil Khol Ke

---

## 1. BRAND PERSONALITY

| Trait | Description |
|---|---|
| Premium | Feels expensive, polished, high production value |
| Cinematic | Every screen should feel like entering a movie theatre |
| Energetic | Fast animations, bold typography, alive |
| Youthful | Modern, culturally aware, not corporate |
| Memorable | Z icon instantly recognizable at any size |

---

## 2. COLOR PALETTE

### Primary Colors
| Name | HEX | RGB | Usage |
|---|---|---|---|
| Primary Black | `#0A0A0A` | 10, 10, 10 | Main app background |
| Surface Dark | `#1A1A1A` | 26, 26, 26 | Cards, sheets, modals |
| Elevated Surface | `#242424` | 36, 36, 36 | Input fields, elevated cards |

### Accent Colors (The ZENO Gradient)
| Name | HEX | RGB | Usage |
|---|---|---|---|
| Accent Red | `#E8002D` | 232, 0, 45 | Primary CTAs, active states |
| Accent Orange | `#FF6B00` | 255, 107, 0 | Gradient midpoint, highlights |
| Glow Hot | `#FF1744` | 255, 23, 68 | Glow effects, hover states |
| Warm White | `#FFF5F0` | 255, 245, 240 | Logo text, headings |

### Supporting Colors
| Name | HEX | RGB | Usage |
|---|---|---|---|
| Text Primary | `#FFFFFF` | 255, 255, 255 | Main text |
| Text Secondary | `#AAAAAA` | 170, 170, 170 | Subtitles, metadata |
| Text Muted | `#666666` | 102, 102, 102 | Captions, timestamps |
| Border | `#2A2A2A` | 42, 42, 42 | Dividers, card borders |
| Overlay | `#000000CC` | 0, 0, 0 @ 80% | Video controls overlay |

### Gradient Definitions
```
Logo Glow:      linear-gradient(135deg, #E8002D → #FF6B00 → #FFF5F0)
Primary Button: linear-gradient(135deg, #E8002D → #FF6B00)
Hero Glow:      radial-gradient(ellipse, #E8002D22 → transparent)
Background:     radial-gradient(ellipse at 30% 50%, #1A0505 → #0A0A0A)
```

---

## 3. TYPOGRAPHY

### Recommended Typefaces
| Role | Font | Weight | Notes |
|---|---|---|---|
| Primary UI | **Inter** | 400–800 | Clean, legible, modern |
| Alternative | **Plus Jakarta Sans** | 400–800 | Slightly more personality |
| Logo/Display | **Sora** or **Urbanist** | 700–900 | Rounded, premium feel |
| Tagline | **Inter** | 300–400 italic | Light, elegant |

### Type Scale
| Level | Size | Weight | Line Height | Usage |
|---|---|---|---|---|
| Display | 56sp | 800 | 1.1 | App logo, hero title |
| H1 | 32sp | 700 | 1.2 | Screen titles |
| H2 | 24sp | 600 | 1.3 | Section headers |
| H3 | 20sp | 600 | 1.4 | Card titles |
| Body L | 16sp | 400 | 1.6 | Descriptions |
| Body M | 14sp | 400 | 1.6 | UI text, labels |
| Caption | 12sp | 400 | 1.5 | Metadata, timestamps |
| Button | 14sp | 700 | 1.0 | All button text |
| Tag/Badge | 11sp | 600 | 1.0 | Genre chips, ratings |

### Letter Spacing
- Display/Logo: `-0.5px` (tight, cinematic)
- Headings: `-0.3px`
- Body: `0px` (default)
- Captions/Tags: `+0.5px` (slightly tracked)
- ALL CAPS labels: `+1.5px`

---

## 4. LOGO SYSTEM

### Logo Files
| File | Usage |
|---|---|
| `zeno_logo_main_dark.png` | Primary — dark backgrounds, app header |
| `zeno_logo_light_mode.png` | Light backgrounds, web, press kit |
| `zeno_logo_horizontal.png` | App top bar, web header, banners |
| `zeno_logo_with_tagline.png` | Onboarding, splash, marketing |
| `zeno_icon_mark.png` | Standalone Z mark — social media, favicon |
| `zeno_app_icon.png` | Android/iOS app store icon |

### Clear Space Rule
Minimum clear space around the logo = **1× the height of the letter E** in the wordmark on all sides.

### Minimum Sizes
| Format | Minimum Size |
|---|---|
| Wordmark (horizontal) | 120px wide |
| Icon mark (Z) | 32px wide |
| App icon | 48×48px |

### Logo Don'ts
- Never change the gradient colors
- Never use on a non-dark, non-white background without testing contrast
- Never stretch, skew, or rotate
- Never add drop shadows (the glow is built in)
- Never use outline/stroke version — use the solid fills only
- Never place on busy photographic backgrounds without an overlay

---

## 5. APP ICON

**File:** `zeno_app_icon.png`

The icon features:
- **Shape:** Rounded square (Google Play / iOS standard)
- **Background:** Deep black `#0A0A0A`
- **Mark:** Bold Z with lightning slash + embedded play triangle
- **Colors:** Red → Orange → White hot center glow
- **Feel:** Recognizable at 48px, striking at 512px

### Android Mipmap Sizes
| Density | Launcher | Foreground |
|---|---|---|
| mdpi | 48×48px | 108×108px |
| hdpi | 72×72px | 162×162px |
| xhdpi | 96×96px | 216×216px |
| xxhdpi | 144×144px | 324×324px |
| xxxhdpi | 192×192px | 432×432px |

---

## 6. SPLASH SCREEN

**File:** `zeno_splash_screen.png`

- **Ratio:** 9:16 (portrait mobile)
- **Background:** Deep black with warm red radial glow behind logo
- **Logo:** Centered ZENO wordmark, red-orange-white glow
- **Tagline:** "Sab Dekho, Dil Khol Ke" — small, elegant, beneath logo
- **Bottom:** Thin red-orange loading bar

### Flutter Implementation
```dart
// In styles.xml (Android)
<style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
  <item name="android:windowBackground">@drawable/launch_background</item>
</style>

// Background: solid #0A0A0A
// Logo appears in splash_screen.dart animation
```

---

## 7. BUTTON STYLE SYSTEM

**Reference:** `zeno_button_styles.png`

### Primary Button — "Watch Now"
```
Background:    linear-gradient(135deg, #E8002D, #FF6B00)
Text:          #FFFFFF, 14sp, Bold
Border Radius: 12dp
Height:        48dp
Padding:       16dp horizontal
Shadow:        0px 4px 20px #E8002D40
Hover Glow:    0px 0px 24px #FF6B0060
```

### Secondary Button — "Add to List"
```
Background:    transparent
Border:        1.5px solid #E8002D
Text:          #FFFFFF, 14sp, SemiBold
Border Radius: 12dp
Height:        48dp
Hover:         background fills to #E8002D15
```

### Ghost Button — "More Info"
```
Background:    #FFFFFF10  (5% white)
Border:        1px solid #FFFFFF15
Text:          #AAAAAA, 14sp, Medium
Border Radius: 12dp
Height:        48dp
Hover:         background to #FFFFFF18
```

### Icon Button (Player Controls)
```
Size:          48×48dp
Background:    #00000080
Icon Color:    #FFFFFF
Active Color:  #FF6B00
Border Radius: 50% (circle)
```

---

## 8. GLOW & SHADOW RULES

### Logo Glow
```
Type:   Outer glow
Color:  #E8002D at 40% opacity
Blur:   32px
Spread: 0px
Use:    Logo on splash, onboarding, marketing
```

### Card Hover Glow
```
Type:   Box shadow
Color:  #E8002D at 25% opacity
Blur:   20px
Offset: 0px 4px
Use:    Content cards on hover/press
```

### Active/Selected State
```
Type:   Bottom border or underline glow
Color:  #FF6B00
Width:  2px
Glow:   0px 0px 8px #FF6B00
Use:    Active tab, selected category chip
```

### Video Player Controls
```
Overlay: linear-gradient(transparent → #000000CC)
Direction: bottom to top, covering bottom 40% of video
```

---

## 9. SPACING SYSTEM

Based on an 8dp grid:

| Token | Value | Usage |
|---|---|---|
| xs | 4dp | Icon padding, tight gaps |
| sm | 8dp | Between labels, small gaps |
| md | 16dp | Card padding, section gaps |
| lg | 24dp | Screen horizontal padding |
| xl | 32dp | Between major sections |
| xxl | 48dp | Hero section spacing |
| xxxl | 64dp | Full-screen section padding |

### Border Radius
| Token | Value | Usage |
|---|---|---|
| sm | 6dp | Chips, badges, tags |
| md | 12dp | Cards, input fields, buttons |
| lg | 16dp | Bottom sheets, modals |
| xl | 24dp | Large cards, hero images |
| full | 9999dp | Circular elements |

---

## 10. ANIMATION GUIDELINES

### Logo Animation Sequence (2.4 seconds)
```
0ms     — Black screen
100ms   — Z appears as thin stroke, fades from center outward
400ms   — Z stroke fills: red → orange → white hot center glow
700ms   — Z briefly morphs: diagonal slash glows, play triangle flickers inside
1000ms  — Light energy beam travels left to right: Z→E→N→O
1100ms  — E appears with subtle electric flicker
1300ms  — N appears with a single electric spark burst at the middle diagonal
1600ms  — O appears, expands slightly outward (like a portal opening) then settles
1900ms  — All letters glow together at peak brightness
2100ms  — Glow fades to subtle steady state
2200ms  — Tagline fades in below: "Sab Dekho, Dil Khol Ke" — 300ms fade
```

### General Animation Principles
| Principle | Rule |
|---|---|
| Duration | UI transitions: 200–300ms. Page transitions: 350ms. Logo: 2400ms |
| Easing | `Curves.easeOutCubic` for entrances. `Curves.easeInCubic` for exits |
| Stagger | List items: 50ms stagger between each. Max 6 items staggered |
| Scale | Tap feedback: scale down to 0.96, spring back. Duration 150ms |
| Opacity | Fade ins start at 0, end at 1. Never use instant visibility changes |
| Color transitions | Always animate via `AnimatedColor`, duration 200ms |

### Scroll Behavior
- Top bar background: transparent → `#0A0A0AE6` (90% black) on scroll
- Transition duration: 200ms
- Hero banner: parallax at 0.5× scroll speed

---

## 11. HERO BANNER (Home Screen)

**File:** `zeno_hero_banner_bg.png`

- Warm red-orange glow source from left side, fades to pure black on right
- Used as base layer behind featured content thumbnail
- Content thumbnail sits on right 60% of screen
- Left 40% shows: Title, genre, rating, Watch Now button

### Overlay Gradient (on content thumbnail)
```
linear-gradient(
  to right,
  #0A0A0A 0%,
  #0A0A0ACC 40%,
  transparent 70%
)
```

---

## 12. CONTENT CARD DESIGN

### Poster Card (2:3 ratio)
```
Border Radius:  12dp
Aspect Ratio:   2:3 (140×210dp standard)
Overlay:        gradient bottom 30% → black 60% opacity
Title:          14sp Bold White, bottom-left, max 2 lines
Shimmer:        Loading state uses shimmer from left to right
Badge:          Top-right: "FREE" chip — red, 10sp, 600 weight
```

### Episode Card (16:9 ratio)
```
Border Radius:  8dp
Aspect Ratio:   16:9
Progress Bar:   2dp thick, red gradient, bottom of thumbnail
Episode No.:    "E01" badge, top-left
Duration:       Bottom-right, 12sp muted gray
```

---

## 13. BRAND VOICE

| Context | Tone | Example |
|---|---|---|
| App UI | Short, confident | "Watch Now" not "Start Watching This Movie" |
| Onboarding | Warm, exciting | "Cinema ke saath, aapke ghar mein" |
| Error states | Human, not robotic | "Kuch gadbad ho gayi. Dobara try karein." |
| Empty states | Encouraging | "Abhi koi download nahi. Kuch save karein!" |
| Loading | Minimal | Just the spinner — no text needed |

---

## 14. FILE INDEX

| File | Type | Usage |
|---|---|---|
| `zeno_logo_main_dark.png` | PNG 16:9 | Primary logo — dark mode |
| `zeno_logo_light_mode.png` | PNG 16:9 | Light mode / press kit |
| `zeno_logo_horizontal.png` | PNG 16:9 | App header, web navbar |
| `zeno_logo_with_tagline.png` | PNG 16:9 | Onboarding, marketing |
| `zeno_icon_mark.png` | PNG 1:1 | Icon-only, social media |
| `zeno_app_icon.png` | PNG 1:1 | Android/iOS app icon |
| `zeno_splash_screen.png` | PNG 9:16 | Splash screen reference |
| `zeno_hero_banner_bg.png` | PNG 16:9 | Home screen background layer |
| `zeno_button_styles.png` | PNG 16:9 | Button system reference |
| `zeno_color_palette.png` | PNG 16:9 | Color system reference |
