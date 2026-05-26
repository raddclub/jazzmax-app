# ZENO (formerly JazzMAX) — Master Context File
> Read this first. Any Replit account with ORACLE_SSH_KEY + GITHUB_TOKEN + SESSION_SECRET secrets can continue immediately.

## 1. What Is This Project
ZENO is an Android streaming app for Jazz SIM users in Pakistan.
Videos are hosted on JazzDrive (cloud.jazzdrive.com.pk) which is ZERO-RATED on Jazz network.
Users can watch movies/shows with ZERO data cost on Jazz SIM.

**App package:** com.jazzmax.app (display name changed to ZENO)
**GitHub:** raddclub/jazzmax-app (main branch)
**Owner:** Muhammad Rehan (GitHub: raddclub)

## 2. Connect to Everything

### Oracle Server SSH
```bash
node -e "
const key = process.env.ORACLE_SSH_KEY;
const parts = key.split('-----');
const full = '-----'+parts[1]+'-----\n'+parts[2].trim().replace(/ /g,'\n')+'\n-----'+parts[3]+'-----\n';
require('fs').mkdirSync('/home/runner/.ssh',{recursive:true});
require('fs').writeFileSync('/home/runner/.ssh/oracle_key', full, {mode:0o600});
console.log('SSH key ready');
"
ssh -i ~/.ssh/oracle_key -o StrictHostKeyChecking=no ubuntu@92.4.95.252 "echo connected"
```

### GitHub
```bash
# GITHUB_TOKEN secret — push via API (git push blocked in Replit)
curl -H "Authorization: token $GITHUB_TOKEN" -H "User-Agent: ZENO" https://api.github.com/repos/raddclub/jazzmax-app
```

## 3. Infrastructure Map

| Service | Port | Path on Oracle |
|---|---|---|
| Radd Hub (admin) | 5000 | /opt/jazzmax/radd-hub/ |
| Watch Prototype (Flutter API) | 6000 | /opt/jazzmax/watch-prototype/ |
| Nginx (public) | 80 | /etc/nginx/sites-available/jazzmax |
| Port 8000 | 8000 | SECURITY ISSUE — exposed publicly, bypass Nginx |

**DB Path:** `/opt/jazzmax/radd-hub/data/radd_hub.db`
**Supervisor:** `sudo supervisorctl status/restart jazzmax_radd / jazzmax_watch`
**Admin URL:** http://92.4.95.252/ (admin / 6LQRmtOM5d1PETSI)

## 4. Database State (as of 2026-05-26)
- 69 total titles (55 movies, 14 shows)
- 20 files total, 20 have share_url (JazzDrive links)
- 15 free titles (is_free=1) — see IDs: 4,12,13,23,26,30,33,35,38,47,57,59,63,68,69
- DB tables: titles, files, app_users, app_subscriptions, tid_payments, app_refresh_tokens, watch_history

## 5. GitHub Repo Structure
```
raddclub/jazzmax-app/
├── jazzmax_flutter/lib/         ← Flutter app (Dart)
│   ├── main.dart                ← Entry point — boots PosterService, JazzDriveService
│   ├── core/
│   │   ├── constants.dart       ← ZENO brand colors (#7B2FFF violet) ✅ UPDATED
│   │   ├── services/
│   │   │   ├── jazzdrive_service.dart  ← On-device zero-rated link generator ✅ BUILT
│   │   │   └── poster_service.dart     ← Smart poster cache ✅ BUILT
│   │   ├── db/
│   │   │   ├── local_db.dart        ← SQLite v10 + stream_cache table ✅ UPDATED
│   │   │   └── sync_service.dart    ← JazzDrive fallback sync ✅ UPDATED
│   │   └── theme/
│   │       ├── app_theme.dart   ← Theme — uses AppColors.primary (ZENO violet) ✅ UPDATED
│   │       └── jazz_colors.dart ← Dark/light color extensions
│   ├── screens/
│   │   ├── splash_screen.dart   ← ZENO animated Z/E/N/O letter icons + particles ✅ REWRITTEN
│   │   ├── onboarding_screen.dart ← ZENO branded icon pages ✅ REWRITTEN
│   │   ├── home_screen.dart     ← ZENO wordmark AppBar + Netflix layout ✅ UPDATED
│   │   ├── player_screen.dart   ← Video player (_openMedia fixed) ✅ FIXED
│   │   ├── show_detail_screen.dart ← Show detail + download buttons ✅ FIXED
│   │   ├── login_screen.dart    ← ZENO branding ✅ UPDATED
│   │   ├── register_screen.dart ← ZENO branding ✅ UPDATED
│   │   ├── profile_screen.dart  ← ZENO branding ✅ UPDATED
│   │   ├── subscription_screen.dart ← ZENO branding ✅ UPDATED
│   │   ├── search_screen.dart   ← ZENO branding ✅ UPDATED
│   │   ├── downloads_screen.dart ← ZENO branding ✅ UPDATED
│   │   ├── vault_screen.dart    ← ZENO branding ✅ UPDATED
│   │   └── vault_lock_screen.dart ← ZENO branding ✅ UPDATED
│   ├── widgets/
│   │   ├── bottom_nav.dart      ← ZENO violet active indicator ✅ UPDATED
│   │   ├── content_card.dart    ← Uses AppColors.primary ✅ OK
│   │   └── notification_banner.dart
│   └── app.dart                 ← ZENO title, ForceUpdate screen updated ✅ UPDATED
├── jazzmax_flutter/pubspec.yaml ← name: zeno, description: ZENO ✅ UPDATED
├── jazzmax_flutter/android/app/src/main/AndroidManifest.xml ← label: ZENO ✅ UPDATED
├── _watch_prototype/routes/     ← Flask API backend
│   ├── app_catalog.py          ← share_url in sync + db_update ✅ FIXED
│   └── jazzdrive_db.py         ← generate_db_update SQL fixed ✅ FIXED
├── JAZZMAX_MASTER_CONTEXT.md    ← This file ✅ UPDATED
└── jazzmax_flutter/TASK_LIST.md ← Phase tracking ✅ UPDATED
```

## 6. ZENO Brand Identity
| Element | Value |
|---|---|
| App name | ZENO |
| Primary color | #7B2FFF (Electric Violet) — ZENO's own brand |
| Accent/Play | #E8002D (Crimson) — for play buttons, energy |
| Background | #08080E (Obsidian black) |
| Z letter color | #E8002D (red → play icon) |
| E letter color | #2F8BFF (blue → eye icon) |
| N letter color | #FFD000 (yellow → lightning bolt) |
| O letter color | #22C55E (green → people icon) |
| Tagline | "Sub Dekho, Dil Kholke" |
| Splash | Animated Z/E/N/O letter icons with particle field |
| Font | Inter (Google Fonts) |
| Android label | ZENO (package ID stays com.jazzmax.app) |

## 7. The Core Zero-Rating System (HOW IT WORKS)
```
User taps Play
  → Check 6h stream cache (SQLite)
  → If cached: play instantly (zero network)
  → If not cached:
      POST cloud.jazzdrive.com.pk/sapi/link/login (ZERO-RATED)
      GET  cloud.jazzdrive.com.pk/sapi/media/video (ZERO-RATED)
      → Get CDN URL (k= token, self-authenticating, NO validationkey needed!)
      → Cache 6h in SQLite
      → Play
Server (92.4.95.252) BYPASSED for playback — only used for catalog sync.
```

**CRITICAL RULE:** Never add `validationkey=` to CDN URLs — the `k=` token is self-authenticating.

## 8. What Has Been Completed

### Phase 0 — Critical Fixes ✅
- Fixed `_openMedia` bug (player was passing JSON API URL to video player)
- Built jazzdrive_service.dart (on-device zero-rated link generation)
- Built poster_service.dart (smart poster caching)
- local_db.dart v10 — stream_cache table, share_url columns
- sync_service.dart — JazzDrive fallback sync
- catalog_api.dart — episodes now parsed from sync response
- show_detail_screen.dart — download buttons on every episode
- main.dart — PosterService.init() + JazzDriveService.loadCacheFromDb()
- app_catalog.py — share_url in /sync and /db_update
- jazzdrive_db.py — fixed broken generate_db_update SQL

### Phase 1 — ZENO Brand Identity ✅
- All Flutter files renamed JazzMAX → ZENO
- constants.dart — Electric Violet #7B2FFF as primary, ZENO Z/E/N/O letter colors
- splash_screen.dart — Animated ZENO logo: Z/E/N/O letter icons appear with colored halos + particle field
- onboarding_screen.dart — Icon-driven pages, ZENO violet CTA buttons
- app.dart — ShaderMask gradient ZENO wordmark in ForceUpdate screen
- home_screen.dart — ShaderMask gradient ZENO wordmark in AppBar, Netflix layout
- pubspec.yaml — name: zeno
- AndroidManifest.xml — android:label="ZENO"

## 9. Remaining Priority Tasks

### 🔴 CRITICAL
- [ ] Verify APK builds successfully on GitHub Actions (push-triggered builds running)
- [ ] Test video playback end-to-end (JazzDriveService → CDN URL → media_kit plays)

### 🟠 HIGH — Flutter UI
- [ ] PHASE 2: Hero banner auto-rotates, Continue Watching row, Trending row
- [ ] PHASE 3: Player — double-tap ±15s, swipe gestures, speed sheet, PiP
- [ ] PHASE 4: Search — live results, filter chips, history
- [ ] PHASE 5: Downloads — folder-based, storage bar, progress ring
- [ ] PHASE 6: Profile — avatar, subscription countdown, theme switcher

### 🟡 MEDIUM
- [ ] Fix 3 broken TMDB poster URLs (Ambulance, 65, Ertugrul)
- [ ] Zero-rated catalog sync — upload db_update.json to JazzDrive, set jazzDriveDbUpdateUrl

### 🟢 LOW — Security
- [ ] Close port 8000 (currently exposed publicly)
- [ ] Move JWT_SECRET + SMS_KEY out of SQLite to env vars

## 10. How to Push Changes
```bash
node -e "
const https = require('https');
const fs = require('fs');
const TOKEN = process.env.GITHUB_TOKEN;
function ghApi(method, path, body, cb) {
  const data = body ? JSON.stringify(body) : null;
  const req = https.request({
    hostname:'api.github.com', path, method,
    headers:{'Authorization':'token '+TOKEN,'User-Agent':'ZENO-Agent',
             'Content-Type':'application/json','Accept':'application/vnd.github.v3+json',
             ...(data?{'Content-Length':Buffer.byteLength(data)}:{})}
  }, res => { let d=''; res.on('data',c=>d+=c); res.on('end',()=>cb(JSON.parse(d))); });
  if(data) req.write(data); req.end();
}
// GET SHA then PUT
ghApi('GET', '/repos/raddclub/jazzmax-app/contents/PATH', null, r => {
  const body = { message: 'msg', content: Buffer.from(fs.readFileSync('file','utf8')).toString('base64') };
  if(r.sha) body.sha = r.sha;
  ghApi('PUT', '/repos/raddclub/jazzmax-app/contents/PATH', body, r => {
    console.log(r.commit ? 'pushed' : r.message);
  });
});
"
# IMPORTANT: Never push multiple files in parallel — SHA conflicts!
# Always push sequentially or wait for each push to complete before next.
```

## 11. Session Log
| Date | Account | Work Done |
|---|---|---|
| 2026-05-25 | Previous #1 | Full architecture, backend, admin panel |
| 2026-05-25 | Previous #2 | Debug logger, APK logs, _openMedia fix, JazzDriveService, PosterService, episode sync, download buttons |
| 2026-05-26 | Previous #3 | Connected Oracle+GitHub, read all files, created this context file |
| 2026-05-26 | Current | Full ZENO rebrand: brand kit generated, constants/splash/onboarding/app/home/all screens updated, AndroidManifest patched, APK builds triggered via push |
