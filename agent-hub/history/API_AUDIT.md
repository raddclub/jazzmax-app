# RaddFlix API Contract Audit — A-to-Z

**Date:** 2026-05-26  
**Auditor:** Replit Agent  
**Scope:** All endpoints in Oracle Watch API (port 6000) vs Flutter app JSON parsing code  
**Status:** ✅ All 12 Bugs Fixed — 2026-05-26  
**Verification:** 24/24 automated backend checks PASS

---

## Executive Summary

| Severity | Count | Description |
|----------|-------|-------------|
| 🔴 CRITICAL | 4 | Runtime crashes or features completely broken |
| 🟠 HIGH | 3 | Wrong data silently displayed to users |
| 🟡 MEDIUM | 3 | Cosmetic or partial data issues |
| 🟢 LOW | 2 | Minor inconsistencies with minimal user impact |

---

## Backend Files Audited

| File | Route Prefix | Status |
|------|-------------|--------|
| `app_auth.py` | `/api/auth/*` | ✅ Audited |
| `app_catalog.py` | `/api/catalog/*` | ✅ Audited |
| `app_search.py` | `/api/search` | ✅ Audited |
| `app_subscription.py` | `/api/subscription/*` | ✅ Audited |
| `app_plans.py` | `/api/plans`, `/api/payment-methods` | ✅ Audited |
| `app_history.py` | `/api/history/*` | ✅ Audited |
| `app_notifications.py` | `/api/notifications/*` | ✅ Audited |
| `watch.py` | `/watch/api/*` | ✅ Audited |

## Flutter Files Audited

| File | Purpose |
|------|---------|
| `models/catalog_item.dart` | CatalogItem model + fromJson |
| `models/user.dart` | AppUser, UserSubscription |
| `models/subscription.dart` | SubscriptionPlan, SubscriptionStatus |
| `core/api/catalog_api.dart` | Catalog API calls |
| `core/api/auth_api.dart` | Auth API calls, LoginResult |
| `core/api/subscription_api.dart` | Subscription API calls |
| `core/db/local_db.dart` | Local SQLite schema + queries |
| `core/db/sync_service.dart` | Oracle + JazzDrive sync logic |
| `core/constants.dart` | ApiPaths constants |
| `providers/auth_provider.dart` | Auth state |
| `providers/catalog_provider.dart` | Catalog state |
| `providers/subscription_provider.dart` | Subscription state |
| `screens/player_screen.dart` | Video player |
| `screens/show_detail_screen.dart` | Show/episode detail |
| `core/services/notification_service.dart` | Notifications |

---

## 🔴 CRITICAL Bugs (crash or complete feature failure)

---

### BUG-001 — `is_free` Bool vs Int in `/api/catalog/sync`

**Severity:** 🔴 CRITICAL  
**Component:** `app_catalog.py` → `CatalogItem.fromJson`  
**Impact:** Entire Oracle catalog sync fails with TypeError OR all content appears as non-free

**Root Cause:**

`/api/catalog/sync` returns:
```python
"is_free": bool(r["is_free"]),   # → JSON true / false
```

`CatalogItem.fromJson` in Flutter:
```dart
isFree: (json['is_free'] as int? ?? 0) == 1,  // expects int!
```

In Dart, `true as int?` throws `TypeError: type 'bool' is not a subtype of type 'int?'`.  
This crashes `CatalogItem.fromJson` for every item returned by `/api/catalog/sync`.

**Contrast:** `/api/catalog/db_update` correctly sends `int`:
```python
"is_free": 1 if r["is_free"] else 0,   # ✅ int
```

**Fix (backend — one line change in `app_catalog.py` sync function):**
```python
# BEFORE:
"is_free": bool(r["is_free"]),

# AFTER:
"is_free": 1 if r["is_free"] else 0,
```

---

### BUG-002 — `media_type` = `"tv"` in DB but Flutter expects `"show"`

**Severity:** 🔴 CRITICAL  
**Component:** `app_catalog.py` sync → `LocalDb.upsertTitle` → `LocalDb.getShows()`  
**Impact:** All TV shows vanish from the home screen shows list after a fresh sync

**Root Cause:**

Backend DB stores `media_type = 'tv'`. Sync returns it verbatim:
```python
"media_type": r["media_type"] or "movie",   # returns 'tv'
```

`LocalDb.upsertTitle` stores `item.mediaType` as-is ('tv').

`LocalDb.getShows()` queries:
```dart
WHERE media_type = 'show'   // never matches 'tv'!
```

`CatalogItem.isShow` checks `mediaType == 'show'` — also fails.

The DB migration at `oldV < 9` converts 'tv' → 'show' for *existing* rows during app upgrade, but new items inserted from Oracle sync bypass the migration entirely.

**Fix (backend — normalize in `app_catalog.py`):**
```python
mt = r["media_type"] or "movie"
# AFTER:
"media_type": "show" if mt in ("tv", "series") else mt,
```

**Alternative fix (Flutter — normalize in `SyncService._persistItems`):**
```dart
// In upsertTitle or before, normalize:
final mediaType = item.mediaType == 'tv' || item.mediaType == 'series' 
    ? 'show' : item.mediaType;
```

---

### BUG-003 — Search: Wrong JSON key `"type"` vs Flutter reading `"media_type"`

**Severity:** 🔴 CRITICAL  
**Component:** `app_search.py` → `CatalogItem.fromJson`  
**Impact:** All TV show search results appear as movies; `isShow` is always false in search

**Root Cause:**

`/api/search` returns:
```python
"type": r["media_type"],   # key is 'type', not 'media_type'!
```

`CatalogItem.fromJson`:
```dart
mediaType: json['media_type'] as String? ?? 'movie',  // reads 'media_type', gets null
```

`json['media_type']` is null → defaults to `'movie'` → all search results are movies.

**Fix (backend — rename key in `app_search.py`):**
```python
# BEFORE:
"type": r["media_type"],

# AFTER:
"media_type": "show" if r["media_type"] in ("tv","series") else (r["media_type"] or "movie"),
```

---

### BUG-004 — Search: Wrong JSON key `"title_id"` vs Flutter reading `"id"`

**Severity:** 🔴 CRITICAL  
**Component:** `app_search.py` → `CatalogItem.fromJson`  
**Impact:** `CatalogItem.fromJson` throws TypeError for every search result (non-nullable `as int`)

**Root Cause:**

`/api/search` returns:
```python
"title_id": r["title_id"],   # key is 'title_id'
```

`CatalogItem.fromJson`:
```dart
id: json['id'] as int,   // 'id' key doesn't exist in search response!
```

`json['id']` is `null`. `null as int` (non-nullable cast) throws `TypeError` in Dart.  
All search results fail to deserialize — search screen shows nothing or crashes.

**Fix (backend — rename key in `app_search.py`):**
```python
# BEFORE:
"title_id": r["title_id"],

# AFTER:
"id": r["title_id"],
```

**Additional note:** The same `is_free` bool bug (BUG-001) also affects search results:
```python
"is_free": bool(r["is_free"]),   # → bool, Flutter expects int
```

---

## 🟠 HIGH Bugs (wrong data silently shown)

---

### BUG-005 — `ShowDetailScreen` reads wrong DB column names for watch progress

**Severity:** 🟠 HIGH  
**Component:** `screens/show_detail_screen.dart` → `LocalDb.getWatchPositions()`  
**Impact:** Episode progress bars never show on show detail screen; all episodes appear unwatched

**Root Cause:**

`LocalDb` `watch_positions` table schema:
```sql
position_ms INTEGER DEFAULT 0,
duration_ms INTEGER DEFAULT 0,
```

`ShowDetailScreen._loadEpisodes()` reads:
```dart
final pos = (p['position'] as int? ?? 0);   // 'position' doesn't exist!
final dur = (p['duration'] as int);          // 'duration' doesn't exist!
```

Both fields return null → `dur` is 0 → progress calculation is skipped → all episodes appear unwatched even if partially watched.

**Fix (Flutter — `show_detail_screen.dart`):**
```dart
// BEFORE:
final pos = (p['position'] as int? ?? 0);
final dur = (p['duration'] as int);

// AFTER:
final pos = (p['position_ms'] as int? ?? 0);
final dur = (p['duration_ms'] as int? ?? 0);
if (dur == 0) continue;  // guard against division by zero
```

---

### BUG-006 — Notification `created_at`: String timestamp, Flutter casts to `int`

**Severity:** 🟠 HIGH  
**Component:** `app_notifications.py` → `AppNotification.fromJson`  
**Impact:** All notification timestamps are 0 (epoch); relative time display always wrong

**Root Cause:**

`user_notifications` table has:
```sql
created_at TEXT DEFAULT CURRENT_TIMESTAMP
```

Backend returns `r["created_at"]` → SQLite string `"2024-01-15 12:30:00"`.

`AppNotification.fromJson`:
```dart
createdAt: j['created_at'] as int? ?? 0,   // String cast to int? = null → defaults to 0
```

**Fix (backend — return Unix timestamp in `app_notifications.py`):**
```python
import time, calendar
from datetime import datetime

def _to_ts(val):
    if val is None: return 0
    if isinstance(val, int): return val
    try:
        dt = datetime.strptime(str(val), "%Y-%m-%d %H:%M:%S")
        return int(calendar.timegm(dt.timetuple()))
    except Exception:
        return 0

# In the notifs list:
"created_at": _to_ts(r["created_at"]),
```

**Alternative fix (Flutter — parse string in `AppNotification.fromJson`):**
```dart
static int _parseTimestamp(dynamic val) {
  if (val == null) return 0;
  if (val is int) return val;
  if (val is String) {
    try { return DateTime.parse(val.replaceFirst(' ', 'T')).millisecondsSinceEpoch ~/ 1000; }
    catch (_) {}
  }
  return 0;
}
// ...
createdAt: _parseTimestamp(j['created_at']),
```

---

### BUG-007 — `SubscriptionPlan.hdAccess` field missing from `/api/subscription/plans`

**Severity:** 🟠 HIGH  
**Component:** `app_subscription.py` PLANS → `SubscriptionPlan.fromJson`  
**Impact:** HD quality indicator always shows `false`; subscription screen never shows HD badge

**Root Cause:**

Backend PLANS dict has no `hd_access` field:
```python
{"id": "basic", "quality": "720p", "downloads": True, ...}  # no hd_access!
```

`SubscriptionPlan.fromJson`:
```dart
hdAccess: (json['hd_access'] as int? ?? 0) == 1,  // field missing → always false
```

**Fix (backend — add `hd_access` to each plan in `app_subscription.py`):**
```python
PLANS = [
    {"id": "free",     "quality": "480p", "hd_access": False, ...},
    {"id": "basic",    "quality": "720p", "hd_access": True,  ...},
    {"id": "standard", "quality": "1080p","hd_access": True,  ...},
    {"id": "premium",  "quality": "1080p","hd_access": True,  ...},
]
```

**Alternative fix (Flutter — derive from `quality` field):**
```dart
hdAccess: (json['hd_access'] as int? ?? 0) == 1 ||
          (json['quality'] as String? ?? '').contains(RegExp(r'720|1080')),
```

---

## 🟡 MEDIUM Bugs (partial or cosmetic data issues)

---

### BUG-008 — `SubscriptionPlan.features` always empty list

**Severity:** 🟡 MEDIUM  
**Component:** `app_subscription.py` PLANS → `SubscriptionPlan.fromJson`  
**Impact:** Subscription screen feature bullet points always empty

**Root Cause:**

Flutter calls `ApiPaths.plans = '/api/subscription/plans'` (hardcoded PLANS in `app_subscription.py`).  
This endpoint has no `features` field in any plan dict.

The DB-driven `/api/plans` (from `app_plans.py`) *does* return `features` from `features_json` column, but Flutter doesn't call that endpoint.

`SubscriptionPlan.fromJson`:
```dart
features: (json['features'] as List<dynamic>? ?? []).cast<String>(),  // always []
```

**Fix (backend — add `features` to hardcoded PLANS in `app_subscription.py`):**
```python
PLANS = [
    {
        "id": "free",
        "features": ["Watch free titles", "480p quality", "Ads supported"],
        ...
    },
    {
        "id": "basic",
        "features": ["All movies & shows", "720p quality", "5 downloads/day", "No ads"],
        ...
    },
    {
        "id": "standard",
        "features": ["All content", "Full HD 1080p", "15 downloads/day", "No ads"],
        ...
    },
    {
        "id": "premium",
        "features": ["All content", "Full HD 1080p", "Unlimited downloads", "Priority support"],
        ...
    },
]
```

---

### BUG-009 — Episode `share_url` missing from `/api/catalog/sync`

**Severity:** 🟡 MEDIUM  
**Component:** `app_catalog.py` sync endpoint  
**Impact:** Zero-rated JazzDrive share links for episodes (TV shows) are null after Oracle sync; only JazzDrive fallback sync includes them

**Root Cause:**

`/api/catalog/sync` episode response:
```python
{
    "id": r["id"],
    "title_id": r["title_id"],
    "file_id": str(r["id"]),
    "season": r["season"],
    "episode": r["episode"],
    "label": f"S{r['season']:02d}E{r['episode']:02d}",
    "is_free": False,
    # ❌ NO share_url field!
}
```

`/api/catalog/db_update` correctly includes `share_url`:
```python
"share_url": r["share_url"] or "",  # ✅ present
```

**Fix (backend — add `share_url` to episode rows in `app_catalog.py` sync):**
```python
# In the episode query, add share_url to SELECT:
ep_rows = c.execute(f"""
    SELECT id, title_id, filename, season, episode, share_url   -- add share_url
    FROM files
    ...
""")

# In the episode dict:
{
    ...
    "share_url": r["share_url"] or "",   # add this line
}
```

---

### BUG-010 — `genres` field: List serialized as `[Action, Drama]` string

**Severity:** 🟡 MEDIUM  
**Component:** `app_catalog.py` sync → `CatalogItem.fromJson` → `LocalDb.upsertTitle`  
**Impact:** Genre filter chips may not work correctly; genre display shows `[Action, Drama]` instead of chips

**Root Cause:**

Backend returns `genres` as a JSON array: `["Action", "Drama"]`.

`CatalogItem.fromJson`:
```dart
genres: json['genres'] is String
    ? json['genres'] as String
    : json['genres']?.toString(),   // List.toString() → "[Action, Drama]"
```

When `genres` is a `List`, `toString()` produces `[Action, Drama]` (with brackets and no quotes) rather than a comma-separated string.

`LocalDb.upsertTitle` stores this `[Action, Drama]` string in the DB.

`ShowDetailScreen._parseGenres` (if it splits on comma) would produce `["[Action", " Drama]"]`.

**Fix (Flutter — in `CatalogItem.fromJson`):**
```dart
genres: json['genres'] is List
    ? (json['genres'] as List).map((e) => e.toString()).join(', ')
    : json['genres'] as String?,
```

---

## 🟢 LOW Bugs (minor, minimal user impact)

---

### BUG-011 — `AppUser.isGuest` not parsed from JSON (always false after deserialization)

**Severity:** 🟢 LOW  
**Component:** `user.dart` → `AppUser.fromJson`  
**Impact:** `AppUser` deserialized from API always has `isGuest=false`; guest state tracked separately via SharedPreferences (works correctly)

**Root Cause:**

`AppUser.fromJson` constructor call:
```dart
return AppUser(
  id: userData['id'] as int? ?? 0,
  phone: userData['phone'] as String? ?? '',
  isActive: (userData['is_active'] as int? ?? 1) == 1,
  // isGuest is NOT parsed — always defaults to false
);
```

Guest state is separately tracked via `SharedPreferences.getBool(StorageKeys.isGuest)` which works, so this is non-critical. But `user.isGuest` will always be false on deserialized users.

**Fix (Flutter — add parsing in `AppUser.fromJson`):**
```dart
isGuest: userData['is_guest'] as bool? ?? false,
```

---

### BUG-012 — `AppUser.isActive` field not returned by `/api/auth/me`

**Severity:** 🟢 LOW  
**Component:** `app_auth.py` `me()` → `AppUser.fromJson`  
**Impact:** `isActive` always defaults to `true` (safe default); no user-facing impact

**Root Cause:**

`/api/auth/me` response:
```python
return jsonify({
    "id": user["id"],
    "phone": user["phone"],
    "device_id": ...,
    # ❌ is_active NOT included
    "subscription": {...},
})
```

`AppUser.fromJson`:
```dart
isActive: (userData['is_active'] as int? ?? 1) == 1,  // field missing → null ?? 1 → true
```

**Fix (backend — add `is_active` to `/api/auth/me` response):**
```python
return jsonify({
    "id": user["id"],
    "phone": user["phone"],
    "is_active": bool(user["is_active"]),   # add this
    ...
})
```

---

## Endpoint-by-Endpoint Status

| Endpoint | Flutter Consumer | Status | Bugs |
|----------|-----------------|--------|------|
| `POST /api/auth/register` | `AuthApi.register()` | ✅ OK | — |
| `POST /api/auth/login` | `AuthApi.login()` | ✅ OK | — |
| `POST /api/auth/guest` | `AuthApi.guestLogin()` | ✅ OK | — |
| `GET /api/auth/me` | `AuthApi.getMe()` | ⚠️ Minor | BUG-012 |
| `POST /api/auth/logout` | `AuthApi.logout()` | ✅ OK | — |
| `POST /api/auth/device` | `AuthApi.bindDevice()` | ✅ OK | — |
| `GET /api/catalog/version` | `CatalogApi.getVersion()` | ✅ OK | — |
| `GET /api/catalog/sync` | `CatalogApi.syncFull/Delta()` | 🔴 BROKEN | BUG-001, BUG-002, BUG-009 |
| `GET /api/catalog/db_update` | `SyncService._syncFromJazzDrive()` | ✅ OK | — |
| `GET /api/search` | `LocalDb.searchTitles()` (local only) | 🔴 BROKEN | BUG-003, BUG-004, BUG-001 |
| `GET /api/subscription/plans` | `SubscriptionApi.getPlans()` | 🟠 PARTIAL | BUG-007, BUG-008 |
| `GET /api/subscription/status` | `SubscriptionApi.getStatus()` | ✅ OK | — |
| `POST /api/subscription/tid/submit` | `SubscriptionApi.submitTid()` | ✅ OK | — |
| `GET /api/subscription/tid/status` | `SubscriptionApi.getTidStatus()` | ✅ OK | — |
| `GET /api/notifications/` | `NotificationService.fetch()` | 🟠 PARTIAL | BUG-006 |
| `POST /api/notifications/read` | `NotificationService.markRead()` | ✅ OK | — |
| `GET /api/history` | (no Flutter consumer found) | ✅ N/A | — |
| `POST /api/history/<file_id>` | (no Flutter consumer found) | ✅ N/A | — |
| `POST /watch/api/play/<file_id>` | `CatalogApi.getStreamUrl()` | ✅ OK | — |

**Note:** Flutter search is currently local-only (`LocalDb.searchTitles`) so BUG-003/004 only affect any future API search calls. But the search API itself is broken if called.

---

## Fix Priority Order

| Priority | Bug | Effort | Impact |
|----------|-----|--------|--------|
| 1 | BUG-001 `is_free` bool→int in sync | 1 line backend | Catalog sync crashes |
| 2 | BUG-002 `media_type` tv→show | 1 line backend | Shows never appear |
| 3 | BUG-005 Episode progress wrong DB columns | 2 lines Flutter | Episodes always show unwatched |
| 4 | BUG-003 Search `type` key | 1 line backend | Wrong search results |
| 5 | BUG-004 Search `title_id` key | 1 line backend | Search crash |
| 6 | BUG-009 Episode share_url missing sync | 3 lines backend | Zero-rated links broken |
| 7 | BUG-006 Notification timestamp string | 5 lines either | Wrong notification times |
| 8 | BUG-007 hdAccess field missing | 4 lines backend | HD badge always off |
| 9 | BUG-008 features always empty | 10 lines backend | Feature list blank |
| 10 | BUG-010 genres list toString | 2 lines Flutter | Genre chip display |
| 11 | BUG-011 isGuest not parsed | 1 line Flutter | Cosmetic only |
| 12 | BUG-012 isActive not in me() | 1 line backend | Cosmetic only |


---

## ✅ Fix Session Summary — 2026-05-26

**All 12 bugs resolved. Automated verification: 24/24 checks PASS.**

### Backend Fixes (Oracle — `/opt/jazzmax/_watch_prototype/routes/`)

| Bug | File | Fix |
|-----|------|-----|
| BUG-001 | `app_catalog.py` + `app_search.py` | `1 if r["is_free"] else 0` (was Python bool → JSON true/false) |
| BUG-002 | `app_catalog.py` | Normalize `"tv"`/`"series"` → `"show"` in sync() |
| BUG-003 | `app_search.py` | Rename JSON key `"type"` → `"media_type"` with normalization |
| BUG-004 | `app_search.py` | Rename JSON key `"title_id"` → `"id"` |
| BUG-006 | `app_notifications.py` | Added `_ts()` helper: SQLite TEXT `"YYYY-MM-DD HH:MM:SS"` → Unix int |
| BUG-007 | `app_subscription.py` | Added `hd_access` field to all 4 PLANS (free=0, others=1) |
| BUG-008 | `app_subscription.py` | Added `features` list to all 4 PLANS (3–6 items each) |
| BUG-009 | `app_catalog.py` | Added `share_url` to episode dict in sync() |
| BUG-012 | `app_auth.py` | Added `is_active` to SQL SELECT + me() return; guest block too |

### Flutter Fixes (GitHub — `raddflix_flutter/lib/`)

| Bug | File | Fix |
|-----|------|-----|
| BUG-005 | `screens/show_detail_screen.dart` | `p['position']`→`p['position_ms']`, `p['duration']`→`p['duration_ms']` |
| BUG-010 | `models/catalog_item.dart` | `genres` List joined as `"Action, Drama"` string, not `.toString()` |
| BUG-011 | `models/user.dart` | `isGuest: userData['is_guest'] as bool? ?? false` |

### Verification

```
PASSED: 24  FAILED: 0
Endpoints tested: /api/catalog/sync, /api/search, /api/subscription/plans, /api/auth/me, /api/notifications/
```

### GitHub Commits

| Files | Commit message |
|-------|----------------|
| `app_catalog.py` | fix(api): BUG-001 is_free int, BUG-002 media_type show, BUG-009 episode share_url |
| `app_search.py` | fix(api): BUG-001 is_free int, BUG-003 media_type key, BUG-004 id key |
| `app_subscription.py` | fix(api): BUG-007 hd_access field, BUG-008 features array |
| `app_notifications.py` | fix(api): BUG-006 created_at string→int Unix timestamp |
| `app_auth.py` | fix(api): BUG-012 is_active field in /me response |
| `show_detail_screen.dart` | fix(flutter): BUG-005 episode progress — position_ms/duration_ms |
| `catalog_item.dart` | fix(flutter): BUG-010 genres List serialized as comma string |
| `user.dart` | fix(flutter): BUG-011 parse isGuest field from JSON |
