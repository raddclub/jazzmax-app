# JazzMAX — Complete Overhaul Task List

## STATUS LEGEND: ⬜ TODO | 🔄 IN PROGRESS | ✅ DONE

---

## PHASE 0: CRITICAL FIXES
- [ ] ✅ Fix radd-hub admin service crash (missing imports)
- [ ] Restart and verify both services running
- [ ] Stop network monitoring interceptors in Flutter (remove dio logging interceptor)

---

## PHASE 1: DESIGN SYSTEM & BRAND IDENTITY
- [ ] Add new packages: flutter_animate, shimmer, lottie, sensors_plus, smooth_page_indicator
- [ ] Create AppTheme system (Dark / AMOLED / Light / Auto + time-based auto-switch)
- [ ] Create ThemeProvider (Riverpod + SharedPreferences persistence)
- [ ] Redesign AppColors: brand red glow, glassmorphism surfaces, deep blacks
- [ ] Add AppShadows: colored glows, layered shadows, backdrop blur
- [ ] Add AppTextStyles: display/headline/body/caption with Inter font
- [ ] Add AppAnimations: shared animation curves and durations
- [ ] Wire ThemeProvider into MaterialApp

---

## PHASE 2: SPLASH & ONBOARDING
- [ ] Splash: animated logo reveal, particle effect bg, smooth transitions
- [ ] Onboarding: hero illustrations, parallax scroll, modern page indicators

---

## PHASE 3: AUTH SCREENS (Login / Register)
- [ ] Login: glassmorphism card, animated bg, brand logo with glow
- [ ] Login: smooth field animations, biometric hint
- [ ] Register: same glassmorphism treatment, animated progress

---

## PHASE 4: HOME SCREEN — Complete Redesign
- [ ] Hero banner/spotlight with auto-scrolling featured content
- [ ] Continue Watching row (resume history from LocalDb)
- [ ] Trending Now row
- [ ] Categories filter chips (Movies / Shows / Dramas / Punjabi / Urdu / English)
- [ ] Recently Added row
- [ ] Animated section headers with count badges
- [ ] Shimmer skeleton loader while syncing
- [ ] Pull-to-refresh with custom animation
- [ ] Sticky/floating animated search bar

---

## PHASE 5: DEDICATED SEARCH SCREEN
- [ ] Full-screen search with animated expansion
- [ ] Search history (recent searches stored locally)
- [ ] Trending searches from server
- [ ] Voice search support
- [ ] Live results with shimmer
- [ ] Filter chips: Genre / Year / Rating / Language / Type
- [ ] Sort options: Newest / Rating / A-Z

---

## PHASE 6: VIDEO PLAYER — Complete Feature Set
- [ ] Playback speed control (0.25x, 0.5x, 0.75x, 1x, 1.25x, 1.5x, 2x)
- [ ] Picture-in-Picture (PiP) support
- [ ] Double-tap left/right seek (10s) with animated ripple
- [ ] Swipe gestures: left=brightness, right=volume, bottom=position scrub
- [ ] Lock screen button (prevents accidental touches)
- [ ] Skip intro button (configurable 85s skip)
- [ ] Next episode button (auto-advance for series)
- [ ] Chapter markers on progress bar
- [ ] Subtitle styling controls (size, color, position)
- [ ] Audio track selection (already has it, keep + improve UI)
- [ ] Subtitle track selection (improve UI)
- [ ] Aspect ratio cycling (keep + add 16:9 specific)
- [ ] Fit/zoom/crop modes
- [ ] Video quality indicator badge (1080p/720p/480p)
- [ ] Animated controls with glass blur background
- [ ] Long-press = 2x speed playback (YouTube style)
- [ ] Pinch-to-zoom
- [ ] Cast button (placeholder for Chromecast future)
- [ ] Rotate to landscape automatic on play
- [ ] Smooth progress bar with chapter thumbnails on drag
- [ ] Animated seek flash (already has it, upgrade animation)
- [ ] Battery & time display in controls

---

## PHASE 7: DOWNLOADS SCREEN — MX Player Style
- [ ] Folder-based organization (Movies / TV Shows / Dramas / Other)
- [ ] Storage usage bar (used vs available)
- [ ] Grid view / List view toggle
- [ ] Sort: By name / Size / Date / Duration
- [ ] Multi-select mode with bulk delete
- [ ] Download queue with pause/resume/cancel
- [ ] Animated progress with speed indicator (MB/s)
- [ ] File size, duration, quality badges on each item
- [ ] Swipe to delete
- [ ] Play directly from grid with play overlay
- [ ] Filter: Completed / Downloading / Failed

---

## PHASE 8: PROFILE SCREEN
- [ ] Avatar with gradient background and initials
- [ ] Subscription expiry countdown
- [ ] Watch stats (hours watched, titles watched)
- [ ] Theme selector (Dark/AMOLED/Light/Auto)
- [ ] Language preference
- [ ] Notification settings
- [ ] About section with version
- [ ] Animated sections

---

## PHASE 9: SUBSCRIPTION SCREEN
- [ ] Dynamic plans from API (already works, improve UI)
- [ ] Animated plan cards with glassmorphism
- [ ] Dynamic payment methods from API (already wired)
- [ ] Copy account number with haptic feedback
- [ ] TID form with animated validation
- [ ] Payment receipt screenshot upload option
- [ ] Real-time subscription status badge

---

## PHASE 10: SECURITY CLEANUP
- [ ] Remove/disable Dio request logging interceptor in production
- [ ] Remove Charles/Proxyman certificate trust from dio options
- [ ] Ensure all API calls go through existing api_client with cert pinning

---

## PHASE 11: ADMIN PANEL — Plans & Billing (already built, verify)
- [ ] Verify plans_panel route works
- [ ] Verify payment_gateway route works
- [ ] Test SMS auto-approval flow
- [ ] Add navigation links for new panels in base.html

---

## PHASE 12: GITHUB PUSH
- [ ] Push all Flutter changes to GitHub
- [ ] Update NEXT_AGENT.md

