# JazzMAX — Master Context File
> Read this first. Any Replit account with ORACLE_SSH_KEY + GITHUB_TOKEN + SESSION_SECRET secrets can continue immediately.

## 1. What Is This Project
JazzMAX is an Android streaming app for Jazz SIM users in Pakistan.
Videos are hosted on JazzDrive (cloud.jazzdrive.com.pk) which is ZERO-RATED on Jazz network.
Users can watch movies/shows with ZERO data cost on Jazz SIM.

**App package:** com.jazzmax.app  
**Owner:** Muhammad Rehan (GitHub: raddclub)

## 2. Connect to Everything

### Oracle Server SSH
```bash
# Key is in ORACLE_SSH_KEY secret (auto-formatted below)
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
# GITHUB_TOKEN secret — use like:
curl -H "Authorization: token $GITHUB_TOKEN" -H "User-Agent: JazzMax" https://api.github.com/repos/raddclub/jazzmax-app
# Repo: raddclub/jazzmax-app (main branch)
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
- 15 free titles (is_free=1)
- DB tables: titles, files, app_users, app_subscriptions, tid_payments, app_refresh_tokens, watch_history

## 5. GitHub Repo Structure
```
raddclub/jazzmax-app/
├── jazzmax_flutter/lib/         ← Flutter app (Dart)
│   ├── main.dart                ← Entry point — boots PosterService, JazzDriveService
│   ├── core/services/
│   │   ├── jazzdrive_service.dart  ← On-device zero-rated link generator ✅ BUILT
│   │   └── poster_service.dart     ← Smart poster cache ✅ BUILT
│   ├── core/db/
│   │   ├── local_db.dart        ← SQLite v10 + stream_cache table ✅ UPDATED
│   │   └── sync_service.dart    ← JazzDrive fallback sync ✅ UPDATED
│   ├── screens/
│   │   ├── player_screen.dart   ← Video player (_openMedia fixed) ✅ FIXED
│   │   ├── home_screen.dart     ← Home (NEEDS REDESIGN)
│   │   └── show_detail_screen.dart ← Show detail + download buttons ✅ FIXED
│   └── core/api/catalog_api.dart  ← Episode sync fix ✅ FIXED
├── _watch_prototype/routes/     ← Flask API backend
│   ├── app_catalog.py          ← share_url in sync + db_update ✅ FIXED
│   └── jazzdrive_db.py         ← generate_db_update SQL fixed ✅ FIXED
├── app-plan/                   ← Architecture plans
│   └── zero_rated_architecture.md ← Full zero-rated plan
├── JAZZMAX_MASTER.md           ← Original master doc
└── NEXT_AGENT.md               ← Handoff notes
```

## 6. The Core Zero-Rating System (HOW IT WORKS)

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

## 7. What The Previous Agent Completed

✅ Fixed `_openMedia` in player_screen.dart (was passing JSON API URL to video player)  
✅ Built jazzdrive_service.dart (on-device zero-rated link generation)  
✅ Built poster_service.dart (smart poster caching)  
✅ local_db.dart — v10 schema, stream_cache table, share_url columns  
✅ sync_service.dart — JazzDrive fallback sync  
✅ catalog_api.dart — episodes now parsed from sync response  
✅ show_detail_screen.dart — local poster + download buttons on episodes  
✅ main.dart — PosterService.init() + JazzDriveService.loadCacheFromDb()  
✅ app_catalog.py — share_url in /sync and /db_update  
✅ jazzdrive_db.py — fixed broken generate_db_update SQL  

## 8. Current Priority Task List

### 🔴 CRITICAL
- [ ] Verify video actually plays end-to-end (JazzDriveService → CDN URL → media_kit)
- [ ] Test APK build on GitHub Actions

### 🟠 HIGH — Flutter UI Redesign (from TASK_LIST.md)
- [ ] PHASE 1: Design system (flutter_animate, shimmer, lottie)
- [ ] PHASE 4: Home screen redesign (Netflix style)
- [ ] PHASE 6: Player complete feature set (double-tap, swipe gestures, PiP, speed)
- [ ] PHASE 7: Downloads screen
- [ ] PHASE 8: Profile screen

### 🟡 MEDIUM
- [ ] Fix is_free resets to 0 on service restart (run: UPDATE titles SET is_free=1 WHERE id IN (4,12,13))
- [ ] Fix 3 broken TMDB poster URLs (Ambulance, 65, Ertugrul)
- [ ] Zero-rated catalog sync — upload db_update.json to JazzDrive
- [ ] Admin: bulk OMDB poster fill + upload to JazzDrive

### 🟢 LOW — Security
- [ ] Close port 8000 (currently exposed publicly)
- [ ] Move JWT_SECRET + SMS_KEY out of SQLite to env vars

## 9. How to Push Changes

```bash
# Via GitHub API (git push blocked in Replit):
node -e "
const https = require('https');
const fs = require('fs');
const content = fs.readFileSync('path/to/file', 'utf8');
const encoded = Buffer.from(content).toString('base64');

// First get current SHA
function ghApi(method, path, body, cb) {
  const req = https.request({
    hostname:'api.github.com', path, method,
    headers:{'Authorization':'token '+process.env.GITHUB_TOKEN,
             'User-Agent':'JazzMax','Content-Type':'application/json'}
  }, res => { let d=''; res.on('data',c=>d+=c); res.on('end',()=>cb(JSON.parse(d))); });
  if(body) req.write(JSON.stringify(body));
  req.end();
}
// GET SHA then PUT
ghApi('GET', '/repos/raddclub/jazzmax-app/contents/path/to/file', null, r => {
  ghApi('PUT', '/repos/raddclub/jazzmax-app/contents/path/to/file', {
    message:'fix: description', content:encoded, sha:r.sha
  }, r => console.log(r.commit ? 'pushed' : r));
});
"
```

## 10. Branding
- Primary: #E8002D (Jazz red)  
- Background: #08080E (Obsidian dark)  
- Surface: #0E0E1C / #151528 / #1C1C35  
- Font: Inter (Google Fonts)

## 11. Session Log
| Date | Account | Work Done |
|---|---|---|
| 2026-05-25 | Previous #1 | Full architecture, backend, admin panel |
| 2026-05-25 | Previous #2 | Debug logger, APK logs, _openMedia fix, JazzDriveService, PosterService, episode sync, download buttons |
| 2026-05-26 | Current | Connected Oracle+GitHub, read all files, created this context file |
