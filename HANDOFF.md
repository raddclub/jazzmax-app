# JazzMAX — Complete Handoff Guide
> This file is for Muhammad Rehan when switching to a new Replit account.
> Everything below is copy-paste ready.

---

## STEP 1 — DO THIS ON THE CURRENT ACCOUNT FIRST (before leaving)

Open the **Replit Shell** tab and run:
```bash
bash push_to_github.sh
```

This pushes everything to: **github.com/raddclub/jazzmax-app** (private repo)
The GITHUB_TOKEN secret is already added, so it should just work.

If it says "nothing to commit" and pushes — perfect, you're done. Move to Step 2.

---

## STEP 2 — SETUP ON THE NEW REPLIT ACCOUNT (mom's account)

### A. Create a new Repl
- Go to replit.com → Create Repl → choose **Python** (or any type, doesn't matter)
- Name it: `jazzmax`

### B. Add these 2 Secrets (Replit sidebar → lock icon 🔒)

| Secret Name | Value |
|---|---|
| `GITHUB_TOKEN` | `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` |
| `SESSION_SECRET` | *(same value you used on the last account — ask yourself, it's in your notes)* |

### C. Open Shell and clone the project
```bash
cd /home/runner
rm -rf workspace
git clone https://$GITHUB_TOKEN@github.com/raddclub/jazzmax-app.git workspace
cd workspace
pip install flask flask-cors pyjwt werkzeug requests
```

### D. Create 2 Workflows (Replit sidebar → wrench icon 🔧)

**Workflow 1:**
- Name: `Radd Hub`
- Command: `cd radd-hub && python3 radd_hub.py run --skip-setup`

**Workflow 2:**
- Name: `Watch Prototype`
- Command: `cd _watch_prototype && PORT=8000 python run.py`

Start both workflows. If they turn green — setup is complete.

---

## STEP 3 — THE EXACT PROMPT TO GIVE THE NEW AGENT

Copy everything between the lines below and paste it as your **first message** to the new agent:

---
```
I am Muhammad Rehan. I am building JazzMAX — an Android-only Flutter streaming app for Jazz SIM users in Pakistan. Jazz SIM users get zero-rated (free data) streaming through JazzDrive CDN. The backend is Python Flask.

READ JAZZMAX_MASTER.md FIRST before doing anything. It has the full project plan, task checklist, all API docs, and session notes.

Here is a summary of what is already done and what to build next:

═══════════════════════════════════════
ALREADY BUILT (Phase 0 — COMPLETE):
═══════════════════════════════════════
1. Flask auth API at _watch_prototype/routes/app_auth.py
   - POST /api/auth/register — register new user
   - POST /api/auth/login — login, returns access + refresh tokens
   - POST /api/auth/refresh — renew access token
   - POST /api/auth/logout — invalidate refresh token
   - GET  /api/auth/me — get logged-in user info
   - POST /api/auth/bind-device — bind device ID to account

2. Catalog sync API at _watch_prototype/routes/app_catalog.py
   - GET /api/catalog/version — check if app needs to sync
   - GET /api/catalog/sync — full catalog sync
   - GET /api/catalog/delta?since=TIMESTAMP — only changed items
   - GET /api/catalog/posters — list of poster image URLs

3. Subscription API at _watch_prototype/routes/app_subscription.py
   - GET  /api/subscription/plans — list available plans
   - GET  /api/subscription/status — check user subscription
   - POST /api/subscription/tid/submit — submit TID payment
   - GET  /api/subscription/tid/status/:tid — check payment status
   - Payment numbers: 03286839827 (Muhammad Rehan, JazzCash + Easypaisa)

4. TID payment verification panel in Radd Hub admin at /tid/

5. Database (SQLite at radd-hub/data/radd_hub.db):
   - app_users table
   - app_subscriptions table
   - app_refresh_tokens table
   - tid_payments table

═══════════════════════════════════════
IMPORTANT TECHNICAL NOTES:
═══════════════════════════════════════
- JWT (PyJWT v2): when signing use "sub": str(user_id), when decoding use options={"verify_sub": False}, when reading use int(payload["sub"])
- SESSION_SECRET env var = JWT signing key (already in Replit Secrets)
- API server runs on port 8000 (Watch Prototype workflow)
- Radd Hub admin runs on port 5000 (Radd Hub workflow)
- Both routes are registered in _watch_prototype/run.py
- Admin routes registered in radd-hub/hub/app.py
- Titles need UPDATE titles SET is_published=1 to appear in catalog
- GitHub repo: github.com/raddclub/jazzmax-app (private, token in GITHUB_TOKEN secret)
- App package: com.jazzmax.app
- GitHub username: raddclub

═══════════════════════════════════════
WHAT TO BUILD NOW (Phase 1 — Flutter):
═══════════════════════════════════════
Create the Flutter Android app. Here are the requirements:

1. Create jazzmax_flutter/ folder in the workspace root
   - Package ID: com.jazzmax.app
   - Android only (no iOS)
   - Min SDK: 21, Target SDK: 34
   - App name: JazzMAX

2. Folder structure (create these files):
   lib/
     main.dart
     app.dart
     core/
       constants.dart        (API base URL, app colors, strings)
       storage.dart          (SharedPreferences wrapper)
       api_client.dart       (Dio HTTP client with auth interceptor — auto refresh token)
     models/
       user.dart
       catalog_item.dart
       subscription.dart
     providers/
       auth_provider.dart    (ChangeNotifier — login/logout/register state)
       catalog_provider.dart (ChangeNotifier — sync catalog, store in SQLite)
       subscription_provider.dart
     screens/
       splash_screen.dart    (check token → route to home or login)
       login_screen.dart
       register_screen.dart
       home_screen.dart      (grid of content, top nav, search)
       player_screen.dart    (video player placeholder for now)
       subscription_screen.dart (plans + TID payment flow)
       profile_screen.dart
     widgets/
       content_card.dart
       bottom_nav.dart
       loading_overlay.dart

3. pubspec.yaml dependencies:
   - dio: ^5.4.0 (HTTP)
   - provider: ^6.1.2 (state)
   - shared_preferences: ^2.2.2 (local storage)
   - sqflite: ^2.3.2 (local catalog DB)
   - cached_network_image: ^3.3.1 (poster images)
   - video_player: ^2.8.2 (video playback)
   - flutter_secure_storage: ^9.0.0 (store JWT tokens)
   - google_fonts: ^6.1.0 (fonts)
   - path_provider: ^2.1.2

4. Design/branding:
   - Primary color: #E31837 (Jazz red)
   - Background: #0A0A0A (near black)
   - Card background: #1A1A1A
   - Text: white
   - Font: Google Fonts — Poppins
   - Style: Netflix-like dark streaming app

5. The API base URL should come from constants.dart:
   - Dev: http://localhost:8000 (for emulator testing)
   - The API is already built and working

6. Auth flow:
   - On app start → check if access token exists in secure storage
   - If yes → validate with GET /api/auth/me → go to home
   - If no → show splash for 2 seconds → go to login
   - Store both access_token and refresh_token in flutter_secure_storage
   - If any API call returns 401 → auto-call /api/auth/refresh → retry

7. After creating all files, also create:
   - .github/workflows/build_apk.yml — GitHub Actions workflow that:
     * Triggers on push to main branch
     * Uses ubuntu-latest
     * Sets up Flutter 3.19.x
     * Runs flutter build apk --release
     * Uploads the APK as a build artifact
     * (No signing needed yet — debug/unsigned release APK is fine)

After building, run: flutter pub get (or equivalent) and make sure there are no obvious errors.

At the end, push everything to GitHub:
bash push_to_github.sh

═══════════════════════════════════════
RULES FOR THIS SESSION:
═══════════════════════════════════════
1. Always read JAZZMAX_MASTER.md first — it has everything
2. At end of session: run "bash push_to_github.sh" from Shell
3. Update JAZZMAX_MASTER.md session notes with what you built
4. Check off completed tasks in JAZZMAX_MASTER.md task checklist
5. Never hardcode the GitHub token in any file — use $GITHUB_TOKEN env var
6. The SQLite database at radd-hub/data/radd_hub.db is important — do not delete it
7. Never run "pip install" for things already in .pythonlibs without checking first
8. If you need to test an API endpoint, curl through localhost:80 not port 8000 directly
```
---

That's the full prompt. Paste it as your first message on the new account.

---

## STEP 4 — WHAT HAPPENS AFTER FLUTTER IS BUILT

Future phases (all documented in JAZZMAX_MASTER.md):

| Phase | What | Est. sessions |
|---|---|---|
| Phase 1 | Flutter scaffold + GitHub Actions APK build | 1 session |
| Phase 2 | Auth screens (login, register, splash) | 1 session |
| Phase 3 | Home screen + catalog sync + poster grid | 1 session |
| Phase 4 | Video player + JazzDrive streaming | 1 session |
| Phase 5 | Subscription flow + TID payment UI | 1 session |
| Phase 6 | Polish, offline mode, push notifications | 1-2 sessions |

---

## QUICK REFERENCE — Key Files

| File | Purpose |
|---|---|
| `JAZZMAX_MASTER.md` | Everything about the project — read first always |
| `HANDOFF.md` | This file — move between accounts |
| `push_to_github.sh` | End of session: saves code to GitHub |
| `create_zip.sh` | Backup: creates zip if GitHub push fails |
| `_watch_prototype/run.py` | Flask app entry point — all API routes registered here |
| `_watch_prototype/routes/app_auth.py` | Auth API |
| `_watch_prototype/routes/app_catalog.py` | Catalog API |
| `_watch_prototype/routes/app_subscription.py` | Subscription + TID payment API |
| `radd-hub/hub/app.py` | Radd Hub admin app — TID panel at /tid/ |
| `radd-hub/hub/db.py` | All database functions |
| `radd-hub/data/radd_hub.db` | SQLite database — DO NOT DELETE |

---

## QUICK REFERENCE — Secrets Needed

| Secret | Value | Where Used |
|---|---|---|
| `GITHUB_TOKEN` | `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` | push_to_github.sh |
| `SESSION_SECRET` | (your value — same across all accounts) | JWT signing key |

---

## QUICK REFERENCE — Payment Info

- **JazzCash:** 03286839827 (Muhammad Rehan)
- **Easypaisa:** 03286839827 (Muhammad Rehan)
- TID payment flow: user pays on Jazz app → enters TID → admin verifies in Radd Hub at `/tid/`

---

## IF GITHUB PUSH FAILS — USE ZIP

```bash
bash create_zip.sh
```
Download `jazzmax_YYYYMMDD_HHMM.zip` → upload to new account → extract:
```bash
python3 -c "import zipfile; zipfile.ZipFile('jazzmax_YYYYMMDD_HHMM.zip').extractall('.')"
pip install flask flask-cors pyjwt werkzeug requests
```
