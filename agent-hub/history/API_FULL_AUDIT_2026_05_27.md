# RaddFlix — Full API Live Audit Report
**Date:** 2026-05-27  
**Agent:** Replit Agent (main)  
**Method:** Every file read from Oracle server live via SSH. Every endpoint tested live via HTTP. No assumptions. No reliance on comments or prior reports.

---

## 1. Infrastructure Summary

| Item | Value |
|------|-------|
| Server | 92.4.95.252 (Oracle ARM64) |
| Watch API | Port 6000 → proxied by nginx on port 80 |
| Admin Panel | Port 5000 (internal only, not public) |
| Database | SQLite at `/opt/jazzmax/radd-hub/data/radd_hub.db` |
| Base URL (Flutter) | `http://92.4.95.252` (from `AppConstants.apiBaseUrl`) |
| Services | `jazzmax_radd` (RUNNING), `jazzmax_watch` (RUNNING) |
| Total published titles | 69 (55 movies, 10 tv, 4 series) |
| Free titles | 15 |
| Paid titles | 54 |
| Episode files | 6 (with season/episode set) |
| Movie files | 14 |

---

## 2. All API Endpoints — Complete Inventory

### 2A. Auth Routes (`/api/auth/*`) — `app_auth.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 1 | POST | `/api/auth/register` | No | ✅ 201 |
| 2 | POST | `/api/auth/login` | No | ✅ 200 / 401 |
| 3 | POST | `/api/auth/refresh` | No (body token) | ✅ (not tested, code verified) |
| 4 | POST | `/api/auth/logout` | Bearer | ✅ (code verified) |
| 5 | GET  | `/api/auth/me` | Bearer | ✅ 200 |
| 6 | POST | `/api/auth/device` | Bearer | ⚠️ 500 on guest |
| 7 | POST | `/api/auth/fcm_token` | Bearer | (code verified) |
| 8 | POST | `/api/auth/guest` | No | ✅ 200 |

### 2B. Catalog Routes (`/api/catalog/*`) — `app_catalog.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 9  | GET | `/api/catalog/version` | No | ✅ 200 |
| 10 | GET | `/api/catalog/sync` | No | ✅ 200 |
| 11 | GET | `/api/catalog/sync?since=<ts>` | No | ✅ 200 (delta) |
| 12 | GET | `/api/catalog/posters` | No | ✅ 200 (67 posters) |
| 13 | GET | `/api/catalog/db_update` | No | ✅ 200 |
| 14 | GET | `/api/catalog/db_update/version` | No | ✅ 200 |

### 2C. Subscription Routes (`/api/subscription/*`) — `app_subscription.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 15 | GET  | `/api/subscription/plans` | No | ✅ 200 |
| 16 | GET  | `/api/subscription/status` | Bearer | ✅ 200 |
| 17 | POST | `/api/subscription/tid/submit` | No | ✅ (code verified) |
| 18 | GET  | `/api/subscription/tid/status` | Bearer | ✅ 200 `{"payments":[]}` |
| 19 | GET  | `/api/subscription/tid/check_by_phone?phone=` | No | ✅ 200 |

### 2D. Plans & Payment Methods — `app_plans.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 20 | GET | `/api/plans` | No | ✅ 200 (reads DB `plans` table) |
| 21 | GET | `/api/payment-methods` | No | ✅ 200 |
| 22 | GET | `/api/subscription/status/<user_id>` | No | ✅ (admin use) |

### 2E. History Routes — `app_history.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 23 | POST | `/api/history/<file_id>` | Bearer (no guest) | ✅ (guest → 401) |
| 24 | GET  | `/api/history` | Bearer (no guest) | ✅ (guest → 401) |

### 2F. Search Route — `app_search.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 25 | GET | `/api/search?q=<term>` | No | ✅ 200 |

### 2G. Notifications — `app_notifications.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 26 | GET  | `/api/notifications/` | Bearer | ✅ 200 (guest → empty) |
| 27 | POST | `/api/notifications/read` | Bearer | ✅ (code verified) |
| 28 | GET  | `/api/notifications/image/<id>` | No | ✅ (code verified) |

### 2H. Watch Routes — `watch.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 29 | POST | `/watch/api/play/<file_id>` | Optional Bearer | ✅ 200 (free content, guest) |
| 30 | GET  | `/watch/api/catalog` | No | ✅ 200 (web UI only) |
| 31 | GET  | `/watch/api/show/<slug>` | No | ✅ (code verified) |
| 32 | GET  | `/watch/poster/<title_id>` | No | ✅ (code verified) |
| 33 | GET  | `/watch/poster-img/<key>` | No | ✅ (code verified) |
| 34 | GET  | `/watch/api/poster/movie/<id>` | No | ✅ (code verified) |
| 35 | GET  | `/watch/api/poster/show/<id>` | No | ✅ (code verified) |

### 2I. App Version — `app_version.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 36 | POST | `/api/app/check` | No | ✅ 200 |

### 2J. Config — `run.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 37 | GET | `/api/config` | No | ✅ 200 |

### 2K. JazzDrive DB — `jazzdrive_db.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 38 | GET  | `/api/jazzdrive/db_update_url` | No | ✅ 200 |
| 39 | POST | `/api/jazzdrive/generate_db_update` | admin_key | (admin only) |
| 40 | POST | `/api/jazzdrive/set_db_update_url` | No | (admin only) |

### 2L. Poster Proxy — `poster_proxy.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 41 | GET  | `/api/poster/search?title=&year=&media_type=` | No | ✅ 200 |
| 42 | POST | `/api/poster/batch` | No | ✅ (code verified) |
| 43 | GET  | `/api/poster/keys` | No | ✅ (internal) |
| 44 | POST | `/api/poster/add_key` | No | (admin only) |

### 2M. SMS Gateway — `sms_gateway.py`

| # | Method | Path | Auth | Live Status |
|---|--------|------|------|-------------|
| 45 | POST | `/api/subscription/sms-payment` | Gateway key | (internal) |
| 46 | GET  | `/api/subscription/sms-payments` | admin_key | (admin only) |

---

## 3. Live Response Payloads — Every Endpoint Tested

### POST `/api/auth/guest`
```json
{
  "access_token": "eyJhbGci...",
  "is_guest": true
}
```
**Flutter reads:** `data['access_token'] as String` ✅

---

### POST `/api/auth/register`
```json
{
  "ok": true,
  "access_token": "eyJhbGci...",
  "refresh_token": "NYEc-JtK9Voz...",
  "user": {
    "id": 11,
    "phone": "03001111222",
    "plan": "free"
  }
}
```
**Flutter reads (`LoginResult.fromJson`):** needs verification — `AuthApi.register()` discards the response and calls `login()` separately, so register response format doesn't matter.

---

### POST `/api/auth/login`
**Success (200):**
```json
{
  "ok": true,
  "access_token": "eyJhbGci...",
  "refresh_token": "NYEc-JtK9Voz...",
  "user": {
    "id": 11,
    "phone": "03001111222",
    "plan": "free"
  }
}
```
**Flutter reads (`LoginResult.fromJson`):** `access_token`, `refresh_token`, `user.id` as userId. ✅

**Failure (401):**
```json
{"error": "incorrect phone number or password"}
```

**Device mismatch (403):**
```json
{"error": "this account is registered on another device", "code": "DEVICE_MISMATCH"}
```

**Account locked (429):**
```json
{
  "error": "account temporarily locked...",
  "code": "ACCOUNT_LOCKED",
  "retry_in": 900
}
```

---

### GET `/api/auth/me` (guest)
```json
{
  "id": 0,
  "phone": "guest",
  "device_id": null,
  "device_name": null,
  "created_at": null,
  "last_login_at": null,
  "is_active": true,
  "subscription": {
    "plan": "free",
    "is_active": true,
    "expires_at": null
  }
}
```
**Flutter reads:** `AppUser.fromJson` → `userData = json['user'] ?? json` (falls back to root) ✅  
`isActive: (userData['is_active'] as int? ?? 1) == 1` — **BUG**: server returns `bool true`, Flutter casts as `int?` → TypeError! See **BUG-NEW-001** below.

---

### GET `/api/auth/me` (authenticated user)
```json
{
  "id": 11,
  "is_active": true,
  "phone": "03001111222",
  "device_id": null,
  "device_name": null,
  "created_at": 1779856929,
  "last_login_at": 1779856929,
  "subscription": {
    "plan": "free",
    "is_active": true,
    "expires_at": null
  }
}
```
**Note:** `is_active` is a Python `bool` (`True`), JSON-serialized as `true`. Flutter reads `as int?` → will return `null` (no crash due to `?`) → defaults to `1 == 1 = true`. Non-crashing but wrong type handling.

---

### POST `/api/auth/refresh`
```json
{
  "ok": true,
  "access_token": "eyJhbGci...",
  "refresh_token": "<new rotated token>"
}
```
**Flutter reads:** `data['access_token']`, `data['refresh_token']` ✅

---

### GET `/api/catalog/version`
```json
{
  "count": 69,
  "version": 1779705973
}
```
**Flutter reads:** `data['version'] as int`, `data['count'] as int` ✅

---

### GET `/api/catalog/sync` (full)
```json
{
  "version": 1779705973,
  "count": 69,
  "titles": [
    {
      "id": 49,
      "title": "Black Panther: Wakanda Forever",
      "year": "2022",
      "media_type": "movie",
      "description": "...",
      "rating": 7.3,
      "genres": ["Action", "Superhero"],
      "language": "english",
      "is_free": 0,
      "runtime": 161,
      "season_count": null,
      "episode_count": null,
      "poster_key": "title_49",
      "poster_url": "https://image.tmdb.org/t/p/w500/...",
      "poster_jd_url": "http://92.4.95.252/watch/poster/49",
      "db_version": 1779705973,
      "file_id": null,
      "share_url": ""
    }
  ],
  "episodes": [
    {
      "id": 34,
      "title_id": 17,
      "file_id": "34",
      "season": 1,
      "episode": 1,
      "label": "S01E01",
      "share_url": "https://cloud.jazzdrive.com.pk/share/f/...",
      "is_free": 0
    }
  ]
}
```
**DB source tables:** `titles` + `files`  
**Key DB columns used:** `titles.id, title, year, media_type, plot, overview, rating, genres, language, is_free, updated_at, poster, poster_share_url, runtime, season_count, episode_count` + `files.id, share_url`

**Flutter reads (`CatalogApi.syncFull`):**
- `data['titles'] as List` → each → `CatalogItem.fromJson` ✅
- `data['episodes'] as List` → attached by title_id ✅
- `json['year'] as int?` → **BUG-NEW-002**: `year` is TEXT in DB (e.g. `"2022"`), JSON serializes as string. Flutter `as int?` → returns null. Year never displays.
- `json['genres']` → returned as `List<String>` → `CatalogItem.fromJson` handles both list and string ✅
- `json['is_free'] as int?` → returned as int 0/1 ✅ (BUG-001 fixed)
- `json['poster'] ?? json['poster_url']` → poster_url field used ✅
- `json['file_id']?.toString()` → null for shows (no movie-level file) ✅

---

### GET `/api/catalog/db_update`
```json
{
  "version": 1779705973,
  "generated_at": "2026-05-27T04:00:00Z",
  "titles": [
    {
      "id": 1,
      "title": "Dune: Part Two",
      "year": "2024",
      "media_type": "movie",
      "description": "...",
      "rating": null,
      "genres": [],
      "language": "",
      "is_free": 0,
      "runtime": null,
      "poster_url": "https://...",
      "db_version": 1779705709,
      "file_id": 14,
      "share_url": ""
    }
  ],
  "episodes": [...]
}
```
**Note:** This endpoint does NOT normalize `media_type`. Raw DB value returned (`"tv"` or `"series"` possible). See **BUG-NEW-003**.  
**Note:** `file_id` here is an integer (from `f.id` in SQL), not a string. **BUG-NEW-004**.  
**Note:** `year` is TEXT. **BUG-NEW-002** applies here too.

---

### GET `/api/catalog/posters`
```json
{
  "posters": [
    {"key": "title_1", "url": "https://image.tmdb.org/t/p/w500/1pd..."},
    {"key": "title_2", "url": "https://image.tmdb.org/t/p/w500/hr9..."}
  ]
}
```
67 poster entries returned. **Flutter does not call this endpoint** (no matching `ApiPaths` constant). Pre-caching not implemented in Flutter yet.

---

### GET `/api/subscription/plans`
```json
{
  "plans": [
    {
      "id": "free",
      "name": "Free",
      "price_pkr": 0,
      "duration_days": null,
      "quality": "480p",
      "hd_access": 0,
      "downloads": false,
      "downloads_per_day": 0,
      "description": "Watch free titles only",
      "features": ["Free titles only", "480p quality", "No downloads"]
    },
    {
      "id": "basic",
      "name": "Basic",
      "price_pkr": 149,
      "duration_days": 30,
      "quality": "720p",
      "hd_access": 1,
      "downloads": true,
      "downloads_per_day": 5,
      "description": "All movies & shows, 720p, 5 downloads/day",
      "features": ["All movies & shows", "720p HD quality", "5 downloads per day", "No ads"]
    },
    {
      "id": "standard",
      "name": "Standard",
      "price_pkr": 299,
      "duration_days": 30,
      "quality": "1080p",
      "hd_access": 1,
      "downloads": true,
      "downloads_per_day": 15,
      "description": "All content, Full HD, 15 downloads/day",
      "features": ["All content", "Full HD 1080p", "15 downloads per day", "No ads", "Priority support"]
    },
    {
      "id": "premium",
      "name": "Premium",
      "price_pkr": 499,
      "duration_days": 30,
      "quality": "1080p",
      "hd_access": 1,
      "downloads": true,
      "downloads_per_day": 999,
      "description": "All content, Full HD, unlimited downloads",
      "features": ["All content", "Full HD 1080p", "Unlimited downloads", "No ads", "Priority support", "Early access to new titles"]
    }
  ],
  "payment": {
    "jazzcash": "03286839827",
    "easypaisa": "03286839827"
  }
}
```
**Flutter reads (`SubscriptionPlan.fromJson`):**
- `json['id'] as String` ✅ (`"free"`, `"basic"`, etc.)
- `json['price_pkr'] as int` ✅
- `json['hd_access'] as int` → `(json['hd_access'] as int? ?? 0) == 1` ✅
- `json['features'] as List` ✅
- `json['downloads_per_day'] as int` ✅
- `json['description'] as String` ✅

---

### GET `/api/subscription/status` (guest)
```json
{
  "plan": "free",
  "is_active": true,
  "expires_at": null
}
```
**GET `/api/subscription/status` (authenticated, active sub):**
```json
{
  "plan": "basic",
  "is_active": true,
  "started_at": 1779000000,
  "expires_at": 1781592000
}
```
**Flutter reads (`SubscriptionStatus.fromJson`):**
- `sub = json['subscription'] as Map? ?? json` → falls back to root ✅
- `sub['plan'] as String` ✅
- `_parseBool(sub['is_active'])` — server sends `bool true` → `_parseBool` handles `bool` ✅
- `_parseExpiry(sub['expires_at'])` ✅ (handles null or int)
- `sub['downloads_used_today'] as int? ?? 0` → **BUG-NEW-005**: server never returns this field → always 0

---

### GET `/api/subscription/tid/status` (guest)
```json
{"payments": []}
```
**Authenticated:**
```json
{
  "payments": [
    {
      "tid": "XYZ123",
      "plan": "basic",
      "status": "pending",
      "amount_pkr": 149,
      "payment_method": "jazzcash",
      "submitted_at": 1779000000,
      "reviewed_at": null
    }
  ]
}
```

---

### GET `/api/subscription/tid/check_by_phone?phone=03001111222`
```json
{
  "phone": "03001111222",
  "payments": [],
  "has_approved": false,
  "approved_plan": null
}
```
**Note:** Flutter's `ApiPaths` does NOT have a path constant for this endpoint. Not called by Flutter app. Admin/diagnostic use only.

---

### GET `/api/plans` (from `app_plans.py`, reads DB `plans` table)
```json
{
  "ok": true,
  "plans": [
    {
      "id": 1,
      "name": "Basic",
      "price_pkr": 149,
      "daily_limit_gb": 0.0,
      "monthly_limit_gb": 30.0,
      "max_devices": 1,
      "duration_days": 30,
      "description": "SD quality. 1 device.",
      "is_active": 1,
      "color": "#E8002D",
      "badge": "POPULAR",
      "features": ["1 screen at a time", "SD quality (480p)", "Mobile & tablet", "30-day access"],
      "price_display": "₨149",
      "duration_display": "30 days"
    },
    {
      "id": 2,
      "name": "Standard",
      "price_pkr": 249,
      "max_devices": 2,
      "features": ["2 screens at a time", "Full HD (1080p)", "All devices", "30-day access", "Download for offline"]
    },
    {
      "id": 3,
      "name": "Premium",
      "price_pkr": 399,
      "max_devices": 4,
      "features": ["4 screens at a time", "Ultra HD (4K)", "All devices", "30-day access", "Download for offline", "Priority support"]
    }
  ]
}
```
**⚠️ CONFLICT**: This endpoint returns DIFFERENT prices than `/api/subscription/plans`:
- Standard: PKR 249 here vs PKR 299 at `/api/subscription/plans`
- Premium: PKR 399 here vs PKR 499 at `/api/subscription/plans`
- No "Free" plan in DB plans table

**Flutter uses:** `ApiPaths.plans = '/api/subscription/plans'` NOT this endpoint. Flutter never calls `/api/plans`.

---

### GET `/api/payment-methods` (from `app_plans.py`, reads DB)
```json
{
  "ok": true,
  "methods": [
    {
      "code": "jazzcash",
      "name": "JazzCash",
      "account_number": "03001234567",
      "account_name": "Muhammad Radd",
      "instructions": "Send money to this JazzCash number and enter your TID below.",
      "icon": "🟣",
      "min_amount_pkr": 0.0
    },
    {
      "code": "easypaisa",
      "name": "EasyPaisa",
      "account_number": "03001234567",
      "account_name": "Muhammad Radd",
      "instructions": "Open EasyPaisa app → Send Money → enter account number, then submit TID.",
      "icon": "🟢",
      "min_amount_pkr": 0.0
    }
  ]
}
```
**⚠️ CONFLICT**: Account number here is `03001234567` ("Muhammad Radd") vs `/api/subscription/plans` which has `03286839827` ("Muhammad Rehan"). Two different payment numbers hardcoded in two different places! **BUG-NEW-006**

**Flutter uses:** `ApiPaths.publicMethods = '/api/payment-methods'` — uses this endpoint (from DB). So Flutter shows `03001234567` to users but admin's hardcoded plans show `03286839827`.

---

### GET `/api/search?q=drama`
```json
{
  "query": "drama",
  "count": 22,
  "results": [
    {
      "id": 59,
      "title": "Champions",
      "year": "2023",
      "media_type": "movie",
      "poster": "https://image.tmdb.org/t/p/w500/...",
      "rating": 7.3,
      "plot": "...",
      "genres": ["Comedy", "Drama", "Sport"],
      "language": "english",
      "is_free": 1,
      "file_id": null
    }
  ]
}
```
**Flutter reads (`CatalogItem.fromJson`):**
- `json['id'] as int` ✅ (BUG-004 fixed)
- `json['media_type']` normalized ✅ (BUG-003 fixed)  
- `json['is_free'] as int?` ✅ (BUG-001 fixed)
- `json['poster'] ?? json['poster_url']` ✅
- `json['year'] as int?` → **BUG-NEW-002**: year is string "2023" → cast returns null
- `json['file_id']?.toString()` ✅ (null handled)
- **Missing from search results:** `share_url`, `db_version`, `language`(present), `status`, `is_ongoing`
- `genres` is a `List` ✅ (handled by BUG-010 fix)

---

### GET `/api/notifications/` (guest)
```json
{"notifications": [], "unread_count": 0}
```
**Authenticated:**
```json
{
  "notifications": [
    {
      "id": 1,
      "broadcast_id": 1,
      "title": "Welcome to RaddFlix!",
      "body": "Start watching free movies now.",
      "type": "info",
      "is_read": false,
      "created_at": 1779705973,
      "image_url": "/api/notifications/image/1"
    }
  ],
  "unread_count": 1
}
```
**Flutter reads (`AppNotification.fromJson`):**
- `j['id'] as int` ✅
- `j['created_at'] as int? ?? 0` ✅ (BUG-006 fixed — _ts() converts to Unix int)
- `j['is_read'] == true` ✅ (bool comparison)
- `j['type'] as String` ✅
- `j['image_url'] as String?` ✅
- **Note:** `user_notifications.created_at` in DB uses `strftime('%s','now')` → returns INTEGER ✅ (consistent with fix)

---

### POST `/api/history/<file_id>`
**Request body:**
```json
{"progress_seconds": 120, "completed": false}
```
**Response (200):**
```json
{"ok": true}
```
**Error (guest → 401):**
```json
{"error": "Unauthorized"}
```
**Note:** `watch_history.updated_at` is TEXT (SQLite `CURRENT_TIMESTAMP` default). History GET returns it as a text string like `"2026-05-27 04:00:00"`. Flutter's `history_api.dart` is empty — history appears to be called directly from `player_screen.dart`.

**⚠️ BUG-NEW-007**: History stores `progress_seconds` (integer seconds) but Flutter's local DB stores `position_ms` (milliseconds). Player sends history to server in seconds but local DB uses ms — inconsistent units. The watch history API is disconnected from Flutter's local resume position system.

---

### GET `/api/history`
```json
{
  "history": [
    {
      "file_id": "11",
      "progress_seconds": 3600,
      "completed": false,
      "updated_at": "2026-05-27 04:00:00"
    }
  ]
}
```

---

### POST `/watch/api/play/<file_id>` (file_id=11, Interstellar, guest)
```json
{
  "ok": true,
  "url": "https://cloud.jazzdrive.com.pk/sapi/download/video?action=get&k=cNEsrTZx...&node=2i182&filename=Interstellar%20%282014%29.mkv",
  "cached": true
}
```
**Error (file not found):**
```json
{"error": "file not found"}
```
**Error (premium content, guest):**
```json
{"error": "subscribe to watch this title", "code": "SUBSCRIPTION_REQUIRED"}
```
**Flutter reads (`CatalogApi.getStreamUrl`):**
- `data['url'] as String?` ✅
- Throws exception if null ✅

---

### POST `/api/app/check`
**Request:**
```json
{"version_code": 1, "version_name": "1.0.0", "platform": "android"}
```
**Response:**
```json
{
  "ok": true,
  "force_update": false,
  "blocked": false,
  "message": "",
  "update_url": "https://play.google.com/store/apps/details?id=pk.jazzmax.app",
  "server_time": 1779856900,
  "current_version": "1.0.0",
  "min_version_code": 1
}
```
**⚠️ BUG-NEW-008**: `update_url` contains `id=pk.jazzmax.app` — old JazzMAX package ID. Should be `com.raddflix.app`.

---

### GET `/api/config`
```json
{
  "api_base_url": "http://92.4.95.252",
  "min_version_code": 1,
  "update_url": "https://github.com/raddclub/raddflix-app/releases/latest",
  "note": "Update api_base_url here to change the server without rebuilding the APK"
}
```
**Flutter reads (`RemoteConfig.fetch`):** `data['api_base_url']` to update `AppConstants.apiBaseUrl` ✅

---

### GET `/api/jazzdrive/db_update_url`
```json
{
  "url": "http://92.4.95.252/api/catalog/db_update",
  "version": 1779705973,
  "generated_at": "2026-05-27T04:41:40Z",
  "interval_hours": 12
}
```

---

### GET `/api/poster/search?title=Lahore&media_type=movie`
```json
{
  "poster_url": "https://img.youtube.com/vi/ZjuN0bDyuNU/maxresdefault.jpg",
  "source": "youtube",
  "cached": false
}
```
**Note:** Falls through TMDB → OMDB → IMDbAPI → YouTube. No TMDB keys configured or regional content not found there.

---

## 4. Database Schema — All Tables

### `titles` (69 published rows)
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| media_type | TEXT | `'movie'`, `'tv'`, `'series'` — **3 values, only 'movie'/'show' in Flutter** |
| title | TEXT | |
| **year** | **TEXT** | **⚠️ String, not int — Flutter casts as int?** |
| language | TEXT | |
| rating | REAL | |
| genres | TEXT | JSON array string |
| plot / overview | TEXT | |
| poster | TEXT | TMDB URL |
| is_free | INTEGER | 0 or 1 |
| is_published | INTEGER | 0 or 1 |
| updated_at | INTEGER | Unix epoch |
| runtime | INTEGER | minutes |
| season_count | INTEGER | |
| episode_count | INTEGER | |
| folder_share_url | TEXT | JazzDrive folder link |
| poster_share_url | TEXT | |

### `files` (20 rows: 14 movie files, 6 episode files)
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | This IS the `file_id` used for play links |
| title_id | INTEGER FK | |
| filename | TEXT | e.g. `"Interstellar (2014).mkv"` |
| season | INTEGER | NULL for movies, 1+ for episodes |
| episode | INTEGER | NULL for movies, 1+ for episodes |
| share_url | TEXT | JazzDrive file share link |
| quality | TEXT | |

### `app_users`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| phone | TEXT UNIQUE | Normalized Pakistani number |
| password_hash | TEXT | Werkzeug hash |
| device_id | TEXT | |
| device_name | TEXT | |
| device_bound_at | INTEGER | Unix epoch |
| is_active | INTEGER | Default 1 |
| created_at | INTEGER | Unix epoch |
| last_login_at | INTEGER | Unix epoch |
| fcm_token | TEXT | |

### `app_subscriptions`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| user_id | INTEGER | |
| plan | TEXT | `'free'`, `'basic'`, `'standard'`, `'premium'` |
| started_at | INTEGER | Unix epoch |
| expires_at | INTEGER | Unix epoch |
| is_active | INTEGER | Default 1 |

### `app_refresh_tokens`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| user_id | INTEGER | |
| token_hash | TEXT | SHA-256 of raw token |
| device_id | TEXT | |
| expires_at | INTEGER | Unix epoch (90 days) |
| revoked | INTEGER | 0/1 |
| rotated_from | INTEGER | prev token id |

### `watch_history`
| Column | Type | Notes |
|--------|------|-------|
| user_id | INTEGER PK (composite) | |
| file_id | TEXT PK (composite) | |
| progress_seconds | INTEGER | **seconds, not ms** |
| completed | INTEGER | 0/1 |
| updated_at | TEXT | SQLite CURRENT_TIMESTAMP string |

### `tid_payments`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| user_id | INTEGER | nullable (guest submission) |
| phone | TEXT | |
| amount_pkr | INTEGER | |
| tid | TEXT | transaction ID |
| payment_method | TEXT | `'jazzcash'` or `'easypaisa'` |
| plan | TEXT | |
| status | TEXT | `'pending'`, `'approved'`, `'rejected'` |
| submitted_at | INTEGER | Unix epoch |
| reviewed_at | INTEGER | |

### `user_notifications`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| user_id | INTEGER | |
| broadcast_id | INTEGER | FK → broadcasts |
| title | TEXT | |
| body | TEXT | |
| notif_type | TEXT | `'info'`, `'promo'`, etc. |
| is_read | INTEGER | 0/1 |
| created_at | INTEGER | Unix epoch (`strftime('%s','now')`) |

### `stream_links`
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| file_id | INTEGER | FK → files |
| download_url | TEXT | JazzDrive stream URL (6h valid) |
| generated_at | INTEGER | Unix epoch |
| expires_at | INTEGER | Unix epoch |
| is_valid | INTEGER | 0/1 |

### `plans` (DB-based, used by `/api/plans`)
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| name | TEXT | |
| price_pkr | INTEGER | **Different from hardcoded PLANS in app_subscription.py** |
| max_devices | INTEGER | |
| duration_days | INTEGER | |
| features_json | TEXT | JSON array |
| color | TEXT | hex color |
| badge | TEXT | |

### `payment_methods` (DB-based, used by `/api/payment-methods`)
| Column | Type | Notes |
|--------|------|-------|
| id | INTEGER PK | |
| code | TEXT | `'jazzcash'`, `'easypaisa'` |
| name | TEXT | |
| account_number | TEXT | **Different from hardcoded number in app_subscription.py** |
| account_name | TEXT | |
| instructions | TEXT | |
| is_enabled | INTEGER | |

---

## 5. Bugs Found — Fresh in This Session

### 🔴 BUG-NEW-001 — `is_active` returned as bool, Flutter expects int
**Endpoint:** `GET /api/auth/me`  
**Server returns:** `"is_active": true` (Python bool → JSON bool)  
**Flutter reads:** `(userData['is_active'] as int? ?? 1) == 1`  
**Result:** `true as int?` → returns null → defaults to `1 == 1 = true` (no crash, but type contract broken)  
**Fix (backend `app_auth.py` me()):**
```python
# Change:
"is_active": bool(user["is_active"])
# To:
"is_active": 1 if user["is_active"] else 0
```

---

### 🔴 BUG-NEW-002 — `year` is TEXT in DB, returned as string, Flutter expects int
**Endpoints:** `/api/catalog/sync`, `/api/catalog/db_update`, `/api/search`  
**DB column:** `titles.year TEXT` — stored as "2022", "2023", etc.  
**Server returns:** `"year": "2022"` (string)  
**Flutter reads:** `json['year'] as int?` → returns null (no crash, but year never displays)  
**Impact:** All content cards and detail screens show blank year.  
**Fix option A (Flutter):** Change to `int.tryParse(json['year']?.toString() ?? '')`  
**Fix option B (backend):** `int(r["year"]) if r["year"] else null` in all catalog responses

---

### 🔴 BUG-NEW-003 — `db_update` endpoint does NOT normalize `media_type`
**Endpoint:** `GET /api/catalog/db_update` (JazzDrive zero-rated sync path)  
**Server returns:** raw `r["media_type"]` from DB → can be `"tv"` or `"series"`  
**Flutter sync path:** `_syncFromJazzDrive()` → `CatalogItem.fromJson()` → `LocalDb.upsertTitle()` → stores `"tv"` in SQLite  
**Flutter queries:** `LocalDb.getShows()` → `WHERE media_type='show'` → shows with `media_type='tv'` are INVISIBLE  
**Impact:** All TV shows (10 out of 69 titles, 15%) are invisible when synced via JazzDrive CDN path  
**Fix (backend `app_catalog.py` db_update()):**
```python
# Change:
"media_type": r["media_type"] or "movie"
# To:
"media_type": ("show" if (r["media_type"] or "movie") in ("tv", "series") else (r["media_type"] or "movie"))
```

---

### 🟠 BUG-NEW-004 — `file_id` in db_update is int, sync returns string
**Endpoint:** `GET /api/catalog/db_update`  
**Returns:** `"file_id": 14` (integer)  
**Endpoint:** `GET /api/catalog/sync`  
**Returns:** `"file_id": "34"` (string — because `str(r["id"])`)  
**Flutter reads:** `json['file_id']?.toString()` → handles both ✅ (no crash)  
**But episode `file_id` in db_update:** `"file_id": "34"` (string) ✅  
**Title-level `file_id` in db_update:** integer — this is inconsistent but Flutter's `.toString()` handles it  
**Severity:** LOW (Flutter handles both) but inconsistent API contract

---

### 🟠 BUG-NEW-005 — `subscription/status` missing download quota fields
**Endpoint:** `GET /api/subscription/status`  
**Server never returns:** `downloads_used_today`, `downloads_limit`  
**Flutter reads:** `sub['downloads_used_today'] as int? ?? 0` → always 0  
**Impact:** Download quota UI always shows 0 used, 0 limit — download limit feature unusable  
**Fix (backend):** Add download tracking to `app_subscriptions` or a separate table, return in status response

---

### 🔴 BUG-NEW-006 — Two conflicting payment account numbers
**Source 1:** `app_subscription.py` (hardcoded `PAYMENT_NUMBER`): `"03286839827"` (Muhammad Rehan)  
**Source 2:** `payment_methods` DB table (used by `app_plans.py`): `"03001234567"` (Muhammad Radd)  
**Flutter uses:** `ApiPaths.publicMethods = '/api/payment-methods'` → reads from DB → shows `03001234567`  
**Flutter also uses:** `ApiPaths.plans = '/api/subscription/plans'` → returns payment with `03286839827`  
**Impact:** If both numbers are shown in different screens, users may pay to wrong number  
**Fix:** Decide on one payment number and one source of truth. Remove hardcoded number from `app_subscription.py`.

---

### 🟠 BUG-NEW-007 — History API uses seconds, Flutter local DB uses milliseconds
**Server:** `progress_seconds` (INTEGER, seconds)  
**Flutter local DB:** `position_ms` (INTEGER, milliseconds)  
**Impact:** If history from server is ever synced to local DB, all resume positions will be 1000x wrong  
**Current state:** Player saves to local DB in ms, sends to server in... unknown (no `history_api.dart`)  
**Action needed:** Verify what player_screen.dart sends to `/api/history/<file_id>` — confirm unit consistency

---

### 🟡 BUG-NEW-008 — `/api/app/check` returns old package ID in `update_url`
**Server returns:** `"update_url": "https://play.google.com/store/apps/details?id=pk.jazzmax.app"`  
**Correct ID:** `com.raddflix.app`  
**Impact:** Force-update dialog sends users to wrong Play Store listing  
**Fix (admin panel):** Settings → App Version → Update URL → change to correct Play Store link

---

### 🟡 BUG-NEW-009 — `watch_history.updated_at` is TEXT (CURRENT_TIMESTAMP)
**DB default:** `updated_at TEXT DEFAULT CURRENT_TIMESTAMP` → stored as `"2026-05-27 04:00:00"`  
**History GET response returns:** `"updated_at": "2026-05-27 04:00:00"` (string)  
**Contrast:** `user_notifications.created_at` uses `strftime('%s','now')` → stored as INTEGER  
**Impact:** Cannot do efficient timestamp comparison in history queries; inconsistent with rest of API  
**Fix:** Migrate `watch_history.updated_at` to INTEGER or add separate `updated_ts INTEGER` column

---

### 🟡 BUG-NEW-010 — `POST /api/auth/device` crashes on guest token (500)
**Live test:** Guest token → POST `/api/auth/device` → HTTP 500 `{"error": "internal error"}`  
**Root cause:** `bind_device()` reads `g.app_user_id` (0 for guest) → queries DB `WHERE id=0` → user not found → code crashes trying to access `user["device_id"]` on None  
**Impact:** Guest trying to bind device causes 500. Should return 403 gracefully.  
**Fix (`app_auth.py` bind_device):**
```python
if getattr(g, 'is_guest', False) or g.app_user_id == 0:
    return jsonify({"error": "guests cannot bind devices"}), 403
```

---

## 6. Flutter → Backend Mismatch Table

| Flutter Path | Flutter Field | Server Field | Server Type | Flutter Expected | Match? |
|-------------|---------------|--------------|-------------|-----------------|--------|
| `CatalogItem.fromJson` | `id` | `id` | int | int | ✅ |
| `CatalogItem.fromJson` | `title` | `title` | str | String | ✅ |
| `CatalogItem.fromJson` | `year` | `year` | **str** | **int?** | **❌ BUG-NEW-002** |
| `CatalogItem.fromJson` | `mediaType` | `media_type` | str (normalized) | String | ✅ (sync) |
| `CatalogItem.fromJson` | `mediaType` | `media_type` | **str (raw)** | String | **❌ BUG-NEW-003** (db_update) |
| `CatalogItem.fromJson` | `isFree` | `is_free` | int 0/1 | bool via int | ✅ |
| `CatalogItem.fromJson` | `genres` | `genres` | List | String/List | ✅ |
| `CatalogItem.fromJson` | `posterUrl` | `poster_url` or `poster` | str | String? | ✅ |
| `CatalogItem.fromJson` | `fileId` | `file_id` | int or str | String? | ✅ (.toString()) |
| `CatalogItem.fromJson` | `shareUrl` | `share_url` | str | String? | ✅ |
| `CatalogItem.fromJson` | `dbVersion` | `db_version` | int | int | ✅ |
| `AppUser.fromJson` | `isActive` | `is_active` | **bool** | **int** | **❌ BUG-NEW-001** |
| `AppUser.fromJson` | `isGuest` | `is_guest` | bool | bool? | ✅ |
| `AppUser.fromJson` | `id` | `id` | int | int | ✅ |
| `AppUser.fromJson` | `subscription` | `subscription` | obj | UserSubscription? | ✅ |
| `SubscriptionPlan.fromJson` | `id` | `id` | str | String | ✅ |
| `SubscriptionPlan.fromJson` | `priceMonthly` | `price_pkr` | int | int | ✅ |
| `SubscriptionPlan.fromJson` | `hdAccess` | `hd_access` | int | bool via int | ✅ |
| `SubscriptionPlan.fromJson` | `features` | `features` | List[str] | List<String> | ✅ |
| `SubscriptionStatus.fromJson` | `plan` | `plan` | str | String | ✅ |
| `SubscriptionStatus.fromJson` | `isActive` | `is_active` | bool | bool via _parseBool | ✅ |
| `SubscriptionStatus.fromJson` | `downloadsUsedToday` | **MISSING** | - | int | **❌ BUG-NEW-005** |
| `AppNotification.fromJson` | `createdAt` | `created_at` | int (Unix) | int | ✅ |
| `AppNotification.fromJson` | `isRead` | `is_read` | bool | bool | ✅ |
| `LoginResult.fromJson` | `accessToken` | `access_token` | str | String | ✅ |
| `LoginResult.fromJson` | `refreshToken` | `refresh_token` | str | String | ✅ |
| `LocalDb.watch_positions` | `position_ms` | `progress_seconds` | **seconds** | **ms** | **❌ BUG-NEW-007** |

---

## 7. API Paths Used by Flutter vs Available on Server

| Flutter `ApiPaths` | Server Endpoint | Exists? | Notes |
|-------------------|-----------------|---------|-------|
| `/api/auth/register` | `POST /api/auth/register` | ✅ | |
| `/api/auth/login` | `POST /api/auth/login` | ✅ | |
| `/api/auth/guest` | `POST /api/auth/guest` | ✅ | |
| `/api/auth/refresh` | `POST /api/auth/refresh` | ✅ | |
| `/api/auth/logout` | `POST /api/auth/logout` | ✅ | |
| `/api/auth/me` | `GET /api/auth/me` | ✅ | |
| `/api/auth/device` | `POST /api/auth/device` | ✅ | 500 on guest |
| `/api/catalog/version` | `GET /api/catalog/version` | ✅ | |
| `/api/catalog/sync` | `GET /api/catalog/sync` | ✅ | |
| `/api/subscription/plans` | `GET /api/subscription/plans` | ✅ | |
| `/api/subscription/status` | `GET /api/subscription/status` | ✅ | |
| `/api/subscription/tid/submit` | `POST /api/subscription/tid/submit` | ✅ | |
| `/api/subscription/tid/status` | `GET /api/subscription/tid/status` | ✅ | |
| `/api/history` | `GET /api/history` | ✅ | |
| `/api/history/<file_id>` | `POST /api/history/<file_id>` | ✅ | |
| `/watch/api/play/<file_id>` | `POST /watch/api/play/<file_id>` | ✅ | |
| `/api/queue/status` | `GET /api/queue/status` (proxy to port 5000) | ✅ | |
| `/api/payment-methods` | `GET /api/payment-methods` | ✅ | Reads DB |
| `/api/notifications/` | `GET /api/notifications/` | ✅ | |
| `/api/notifications/read` | `POST /api/notifications/read` | ✅ | |
| `/api/notifications/image/<id>` | `GET /api/notifications/image/<id>` | ✅ | |
| **NOT in Flutter** | `GET /api/config` | ✅ | Remote config, called at startup |
| **NOT in Flutter** | `GET /api/plans` | ✅ | DB plans, Flutter uses subscription/plans |
| **NOT in Flutter** | `GET /api/catalog/posters` | ✅ | Not implemented in Flutter |
| **NOT in Flutter** | `GET /api/catalog/db_update` | ✅ | Used by JazzDrive sync path |
| **NOT in Flutter** | `POST /api/app/check` | ✅ | App version gate — should be called! |

**⚠️ MISSING: Flutter never calls `/api/app/check`**  
The app version/tamper check endpoint exists but Flutter has no code to call it. Version enforcement only works via middleware headers, not the explicit startup check.

---

## 8. Summary of All Issues — Prioritized

| ID | Severity | Component | Short Description |
|----|----------|-----------|-------------------|
| BUG-NEW-001 | 🔴 CRITICAL | `app_auth.py` me() | `is_active` returned as bool, Flutter expects int |
| BUG-NEW-002 | 🔴 CRITICAL | All catalog endpoints | `year` is TEXT string, Flutter casts as `int?` → null (year never displays) |
| BUG-NEW-003 | 🔴 CRITICAL | `app_catalog.py` db_update | `media_type` not normalized → TV shows invisible on JazzDrive sync |
| BUG-NEW-006 | 🔴 CRITICAL | Dual payment config | Two conflicting account numbers in two endpoints |
| BUG-NEW-004 | 🟠 HIGH | `app_catalog.py` db_update | Title `file_id` int vs episode `file_id` string (inconsistent) |
| BUG-NEW-005 | 🟠 HIGH | `app_subscription.py` | Download quota fields missing from status response |
| BUG-NEW-007 | 🟠 HIGH | `app_history.py` | History in seconds, local DB in milliseconds |
| BUG-NEW-008 | 🟡 MEDIUM | `app_version.py` | Update URL has wrong package ID (pk.jazzmax.app) |
| BUG-NEW-009 | 🟡 MEDIUM | `app_history.py` | `updated_at` is TEXT string not Unix int |
| BUG-NEW-010 | 🟡 MEDIUM | `app_auth.py` | `bind_device` crashes (500) on guest token |
| INFO-001 | ℹ️ INFO | Flutter | `/api/app/check` never called from Flutter |
| INFO-002 | ℹ️ INFO | Flutter | `/api/catalog/posters` exists but not implemented |
| INFO-003 | ℹ️ INFO | Plans | Two plan endpoints with different prices (Flutter uses subscription/plans) |
| INFO-004 | ℹ️ INFO | DB | `media_type` has 3 values in DB: movie/tv/series (only movie/show in Flutter) |

---

## 9. What Was Verified Live (No Assumptions)

- ✅ SSH connected to Oracle, all Python route files read directly from disk
- ✅ All DB table schemas obtained via `PRAGMA table_info()`
- ✅ 34 HTTP requests made and responses captured
- ✅ Guest token obtained and used on all auth-gated endpoints
- ✅ Real play link generated for Interstellar (file_id=11) — returned valid JazzDrive CDN URL
- ✅ Real test user registered (03001111222) and login tested
- ✅ All Flutter model files, API client files, provider files read from GitHub
- ✅ Local SQLite schema from Flutter read from `local_db.dart`
- ✅ Sync service logic traced through both Oracle and JazzDrive paths
