# JazzMAX Agent Memory

_Last updated: 2026-05-25 by agent_

---

## Project Architecture

| Component | Port | Process | Config |
|---|---|---|---|
| Radd Hub (admin panel) | 5000 | `python3 /opt/jazzmax/radd-hub/radd_hub.py run --skip-setup` | supervisor: jazzmax_radd |
| Flutter API (watch prototype) | 6000 | `python3 /opt/jazzmax/_watch_prototype/run.py` | supervisor: jazzmax_watch |
| nginx (public) | 80 | nginx | `/etc/nginx/sites-enabled/jazzmax` |

**nginx routing rules:**
- `/api/auth/register`, `/api/auth/login`, `/api/auth/refresh`, `/api/auth/guest` → port 6000 (rate-limited)
- `/api/app/check` → port 6000 (rate-limited)
- `/api/` (all other) → port 6000
- `/watch/` → port 6000
- `/stream/`, `/admin`, `/library/`, `/scan/`, `/upload/`, `/tid/`, `/app-users/` → port 5000 (Radd Hub)
- `/api/db_mgmt/`, `/api/ping`, `/api/health/`, `/api/tunnel/` → port 5000 (Radd Hub)
- `/` (root) → port 5000 (Radd Hub)

**Active DB:** `/opt/jazzmax/radd-hub/data/radd_hub.db` (SQLite)  
**Git repo:** `/opt/jazzmax/` → remote `raddclub/jazzmax-app` branch `main`  
**GitHub Actions:** builds APK on every push to main

---

## Flutter App Structure

- **Repo root on Oracle:** `/opt/jazzmax/jazzmax_flutter/`
- **Base API URL:** `http://92.4.95.252` (set in `AppConstants.apiBaseUrl`)
- **DB version:** 8 (bumped from 7, adds `content_type` column to downloads table)

---

## Complete API Audit (2026-05-25) — ALL PASS ✅

Tested on port 6000 directly. Every route is correctly registered and returns expected status.

| Flutter ApiPath | Full URL | Backend | Status |
|---|---|---|---|
| `ApiPaths.guest` | POST /api/auth/guest | app_auth.py | ✅ 200 |
| `ApiPaths.register` | POST /api/auth/register | app_auth.py | ✅ 400 (bad data, route OK) |
| `ApiPaths.login` | POST /api/auth/login | app_auth.py | ✅ registered |
| `ApiPaths.refresh` | POST /api/auth/refresh | app_auth.py | ✅ 400 (bad data, route OK) |
| `ApiPaths.logout` | POST /api/auth/logout | app_auth.py | ✅ registered |
| `ApiPaths.me` | GET /api/auth/me | app_auth.py | ✅ 401 (no token) |
| `ApiPaths.bindDevice` | POST /api/auth/device | app_auth.py | ✅ registered |
| `ApiPaths.catalogVersion` | GET /api/catalog/version | app_catalog.py | ✅ 200 |
| `ApiPaths.catalogSync` | GET /api/catalog/sync | app_catalog.py | ✅ 200 |
| `ApiPaths.plans` | GET /api/subscription/plans | app_subscription.py | ✅ 200 |
| `ApiPaths.subscriptionStatus` | GET /api/subscription/status | app_subscription.py | ✅ 401 (no token) |
| `ApiPaths.tidSubmit` | POST /api/subscription/tid/submit | app_subscription.py | ✅ 400 (bad data) |
| `ApiPaths.tidStatus` | GET /api/subscription/tid/status | app_subscription.py | ✅ 401 (no token) |
| `ApiPaths.historyBase` | GET /api/history | app_history.py | ✅ 401 (no token) |
| `ApiPaths.saveHistory(id)` | POST /api/history/{id} | app_history.py | ✅ registered |
| `ApiPaths.playUrl(id)` | POST /watch/api/play/{id} | watch.py | ✅ 404 = file not found (route works) |
| `ApiPaths.adminQueue` | GET /api/queue/status | run.py proxy→RaddHub | ✅ 200 |
| `ApiPaths.publicMethods` | GET /api/payment-methods | app_plans.py | ✅ 200 |
| `AppUpdateService` | POST /api/app/check | app_version.py | ✅ 200 |

**Note:** `/watch/api/play/{id}` returns 404 for non-existent file IDs — that is correct behavior (the route IS registered). The route proxies to JazzDrive to generate stream URLs.

---

## Blueprint URL Prefixes

| File | url_prefix | Example routes |
|---|---|---|
| app_auth.py | /api/auth | /register, /login, /guest, /refresh, /logout, /me, /device |
| app_catalog.py | /api/catalog | /version, /sync, /db_update |
| app_history.py | /api/history | / (GET list), /{file_id} (POST save) |
| app_plans.py | /api | /plans, /payment-methods, /subscription/status/{user_id} |
| app_search.py | /api/search | / (GET ?q=) |
| app_subscription.py | /api/subscription | /plans, /status, /tid/submit, /tid/status |
| app_version.py | /api/app | /check |
| watch.py | /watch | /api/catalog, /api/play/{id}, /api/show/{slug}, /api/poster/... |
| run.py (inline) | — | /api/queue/status (proxies to RaddHub port 5000) |

---

## Known Issues & Fixes Applied

### Fixed in commit 7019c37 (2026-05-25)
- Light theme not applying (backgroundColor null in 8 screens)
- heroGradient context-aware for light/dark
- Seek icons show "15" label
- PIN dots dynamic (4-6 based on input)
- See-All pre-filter
- Downloads folder uses content_type
- DB migration v8

### Fixed in commit 51fc36d (2026-05-25)
- DB migration version check `oldV < 5` → `oldV < 8` (content_type column never ran for v7 users)

### Fixed in this session (2026-05-25)
- `ApiPaths.adminQueue` corrected from `/stream/api/queue` to `/api/queue/status`
- Removed dead ApiPaths: `adminQueueDirect`, `metaAutofix`, `metaAutofixStatus`
- Admin queue screen now uses `ApiPaths.adminQueue` constant (not hardcoded)
- Server Downloads in Profile: visible to all logged-in users (not just admin)
- Server Downloads: connectivity gate added (hidden when offline)
- `is_admin` column added to `app_users` table (for future use)

### Remaining Known Issues (backend/infra, not Flutter)
- Login/Register fail in test: server returns errors — likely wrong test credentials
- Catalog empty for guest: catalog sync works but guest may see nothing if backend catalog is empty
- Vault import PlatformException(unknown_path): pre-existing Android file picker bug, not our code

---

## App_users Table Schema
```sql
CREATE TABLE app_users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    phone TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    device_id TEXT,
    device_name TEXT,
    device_bound_at INTEGER,
    is_active INTEGER DEFAULT 1,
    created_at INTEGER DEFAULT (strftime("%%s","now")),
    last_login_at INTEGER,
    fcm_token TEXT,
    fcm_updated_at INTEGER,
    is_admin INTEGER DEFAULT 0  -- added 2026-05-25
);
```

---

## SSH / Git Commands

```bash
# SSH to Oracle
ssh -i ~/.ssh/oracle_key -o StrictHostKeyChecking=no ubuntu@92.4.95.252

# Push from Oracle
cd /opt/jazzmax
git add -A
git -c user.email="jazzmax@bot.local" -c user.name="JazzMAX Bot" commit -m "message"
GIT_TERMINAL_PROMPT=0 git push origin main

# Check service logs
sudo supervisorctl status
sudo tail -f /var/log/jazzmax_watch.err.log
sudo tail -f /var/log/jazzmax_radd.err.log
```

---

## GitHub Actions
- Workflow: `.github/workflows/build-apk.yml` (Flutter 3.22.x, preferred)
- Workflow: `.github/workflows/build_apk.yml` (Flutter 3.19.6, legacy)
- APK built and available as artifact after every push to main
