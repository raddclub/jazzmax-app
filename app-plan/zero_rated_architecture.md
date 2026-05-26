# Zero-Rated Architecture Plan — On-Device Stream Link Generation, Poster Strategy & Encrypted DB
**Created:** 2026-05-25  
**Status:** APPROVED — Ready to build  
**Applies to:** JazzMAX Flutter app (com.jazzmax.app)

---

## Problem Being Solved

Jazz SIM users in Pakistan can access `cloud.jazzdrive.com.pk` for FREE (zero-rated) without any internet data bundle. But our Oracle server (`92.4.95.252`) is NOT zero-rated — reaching it requires a data bundle.

**Current broken flow:**
```
User taps Play → App calls Oracle server → Oracle calls JazzDrive → returns CDN URL → App plays
                 ↑ REQUIRES DATA BUNDLE — kills zero-rating promise
```

**Target flow (fully zero-rated):**
```
User taps Play → App calls cloud.jazzdrive.com.pk directly → gets CDN URL → plays
                 ↑ ZERO-RATED — no data bundle consumed, works for all Jazz SIM users
```

---

## Phase 1 — On-Device Stream Link Generation

### How JazzDrive Link Generation Works (No Login Required)

Every video file is stored in a JazzDrive shared folder. We have the share URL for each file in the catalog. The process to get a direct streamable CDN URL has exactly 2 steps, both to `cloud.jazzdrive.com.pk` (zero-rated):

**Step 1 — Share Login (get a session token)**
```
POST https://cloud.jazzdrive.com.pk/sapi/link/login?action=login
Body: { "data": { "accesstoken": "{shareKey}" } }
Headers:
  Accept: application/json, text/plain, */*
  Content-Type: application/json;charset=UTF-8
  Origin: https://cloud.jazzdrive.com.pk
  Referer: https://cloud.jazzdrive.com.pk/share/f/{shareKey}
  User-Agent: Mozilla/5.0 (Linux; Android 12; SM-A515F) AppleWebKit/537.36 ...
  X-Requested-With: com.jazz.drive

Response: { "data": { "validationkey": "abc123...", ... } }
```
Extract `shareKey` from share URL using regex: `/\/(?:share-landing\/f|share\/f|f)\/([^\/?#]+)/`

**Step 2 — Get Media List (get CDN URL + poster)**
```
GET https://cloud.jazzdrive.com.pk/sapi/media/video?action=get&shared=true&key={shareKey}&validationkey={vk}
Headers: same as above + Cookie: JSESSIONID={jsessionid from Step 1 Set-Cookie header}

Response: {
  "data": {
    "list": [
      {
        "name": "Interstellar (2014).mkv",         ← actual filename with real extension
        "url": "/sapi/download/video?action=get&k=SIGNED_TOKEN&node=N",
        "size": 1234567890,
        "thumbnails": [                             ← JazzDrive poster images
          { "url": "/sapi/download/video?action=get&k=POSTER_TOKEN..." }
        ]
      }
    ]
  }
}
```

**Step 3 — Build Final URL**
```
rawUrl = record.url  (starts with / → prepend cloud.jazzdrive.com.pk)
filename = record.name || record.filename  ← USE THIS, real extension (.mkv not .mp4)
directLink = rawUrl + (has ? ? & : ?) + "filename=" + encodeURIComponent(filename)

CRITICAL: Do NOT append validationkey= to the final URL.
The k= token in the URL is already a signed self-authenticating token.
Adding validationkey breaks the URL. (Verified by live test 2026-05-25)
```

**Poster URL:**
```
thumbnails = record.thumbnails || []
posterUrl = thumbnails[thumbnails.length - 1]?.url || thumbnails[0]?.url
if posterUrl starts with / → prepend cloud.jazzdrive.com.pk
```

### Flutter Implementation: `JazzDriveService` (Dart)

**File:** `lib/core/services/jazzdrive_service.dart`

```dart
class JazzDriveService {
  static const String _cloudBase = 'https://cloud.jazzdrive.com.pk';
  static const Duration _cacheTtl = Duration(hours: 6);

  // In-memory cache: fileId → {url, posterUrl, expiresAt}
  static final Map<String, _LinkCache> _cache = {};

  /// Get a stream URL for a file. Uses cache if still valid (< 6h).
  /// Works with zero-rated Jazz SIM, no Oracle server needed.
  static Future<JazzDriveLink> getStreamLink(String fileId, String shareUrl) async {
    // 1. Check cache
    final cached = _cache[fileId];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return JazzDriveLink(streamUrl: cached.streamUrl, posterUrl: cached.posterUrl);
    }
    // 2. Extract share key
    final shareKey = _extractShareKey(shareUrl);
    if (shareKey == null) throw Exception('Invalid share URL: $shareUrl');
    // 3. Login to share
    final session = await _loginShare(shareKey);
    // 4. Get media list
    final record = await _getMedia(shareKey, session.validationKey, session.cookie, fileId);
    // 5. Build URL (no validationkey appended — k= is self-signing)
    final streamUrl = _buildUrl(record.rawUrl, record.filename);
    final posterUrl = record.posterUrl;
    // 6. Cache result
    _cache[fileId] = _LinkCache(
      streamUrl: streamUrl,
      posterUrl: posterUrl,
      expiresAt: DateTime.now().add(_cacheTtl),
    );
    return JazzDriveLink(streamUrl: streamUrl, posterUrl: posterUrl);
  }

  static String _extractShareKey(String shareUrl) { ... }
  static Future<_ShareSession> _loginShare(String shareKey) { ... }
  static Future<_MediaRecord> _getMedia(shareKey, vk, cookie, fileId) { ... }
  static String _buildUrl(String rawUrl, String filename) { ... }
}
```

**Also persist cache to encrypted SQLite** so it survives app restarts:
- Table: `stream_cache (file_id TEXT PK, stream_url TEXT, poster_url TEXT, expires_at INTEGER)`
- On app start: load cache from DB into memory map (only non-expired rows)
- On new link generated: save to DB

### Changes to Catalog Sync (Backend)

Add `share_url` to every file/episode in the sync response so the app has it locally:

**`app_catalog.py` — `/api/catalog/sync` response:**
```python
# titles: add share_url for movie-type files
"share_url": r["share_url"] or "",   # ← ADD THIS

# episodes: add share_url per episode
"share_url": r["share_url"] or "",   # ← ADD THIS
```

**`local_db.dart` — schema:**
```sql
-- episodes table: add share_url column
ALTER TABLE episodes ADD COLUMN share_url TEXT;
-- New DB version: 10 (increment from 9)
```

---

## Phase 2 — Poster Strategy

### Priority Order

**When user HAS internet (WiFi or mobile data bundle):**
```
1. Already in hidden permanent folder on device?  → show instantly (0 network calls)
2. TMDB URL (from catalog)                        → download, save permanently, show
3. OMDB API                                       → download, save permanently, show
4. IMDb / YouTube / Google                        → download, save permanently, show
5. JazzDrive thumbnails[]                         → LAST RESORT only (see below)
6. Grey placeholder card
```

**When user has NO internet (Jazz SIM only, zero-rated):**
```
1. Already in hidden permanent folder on device?  → show instantly
2. Grey placeholder card (do not try TMDB — not zero-rated)
   ↓ When user taps the content AND stream link is generated:
3. JazzDrive thumbnails[] comes FREE with stream link call → save permanently → show
```

### Background Poster Downloads (when internet available)

- **Source:** TMDB/OMDB only (NOT JazzDrive)
- **Trigger:** App in foreground + WiFi/mobile data detected
- **Rate:** 50–100 images per day max (never spam)
- **What to download:** Missing posters for catalog items (poster not yet in hidden folder)
- **Do NOT:** Auto-download from JazzDrive in background. JazzDrive is on-demand only.

### On-Screen Lazy Loading

- Only load posters for items currently visible on screen
- Cancel pending loads for items scrolled off screen
- Use `CachedNetworkImage` with custom cache manager pointing to hidden folder

### Hidden Permanent Folder

```
Android location: getExternalFilesDir(null) + "/jazzmax_posters/"
  or: getFilesDir() + "/jazzmax_posters/"
  
Properties:
  - Hidden from gallery (MediaStore.NOT_SCANNABLE)
  - Not deleted on app cache clear
  - Deleted only on app uninstall
  - Only our app can read (Android file permissions)
  - File naming: title_{id}.jpg (no collisions even if JazzDrive names all "poster.jpg")
```

**Flutter Implementation: `PosterService`**

```dart
class PosterService {
  static Directory? _posterDir;

  static Future<String?> getPoster(int titleId, {
    String? tmdbUrl,
    String? shareUrl,     // for JazzDrive fallback (when no internet)
    String? fileId,
  }) async {
    // 1. Check permanent folder
    final cached = await _getCached(titleId);
    if (cached != null) return cached;

    // 2. Try TMDB/OMDB (only if has internet)
    if (await _hasInternet() && tmdbUrl != null) {
      return await _downloadAndSave(titleId, tmdbUrl);
    }

    // 3. JazzDrive: only if stream link already generated (poster is free at that point)
    // Called by JazzDriveService when it gets posterUrl from media response
    return null;  // show placeholder; poster will arrive when user taps play
  }

  static Future<void> saveJazzDrivePoster(int titleId, String posterUrl) async {
    if (await _getCached(titleId) != null) return;  // already have it
    await _downloadAndSave(titleId, posterUrl);
  }

  static Future<void> runBackgroundSync(List<CatalogItem> items) async {
    // 50-100 per day from TMDB only
    // Runs silently when app is in foreground with internet
  }
}
```

---

## Phase 3 — Encrypted Local DB + Zero-Rated Catalog Sync

### Encrypted SQLite (SQLCipher)

**Package:** `sqflite_sqlcipher` (Flutter)  
**Key storage:** Android Keystore (hardware-backed, only our app can access)  
**Key generation:** Once on first install, random 256-bit key, stored in Keystore  
**Result:** DB file is encrypted binary — `sqlite3` command cannot open it, root tools cannot read it  

```dart
class SecureDb {
  static Future<Database> open() async {
    final key = await _getOrCreateKey();  // from Android Keystore
    return openDatabaseWithOptions(
      path: 'jazzmax_secure.db',
      password: key,
      options: OpenDatabaseOptions(version: 10, onCreate: _create, onUpgrade: _migrate),
    );
  }

  static Future<String> _getOrCreateKey() async {
    const storage = FlutterSecureStorage();
    String? key = await storage.read(key: 'jm_db_key');
    if (key == null) {
      key = _generateRandomKey(32);  // 256-bit
      await storage.write(key: 'jm_db_key', value: key);
    }
    return key;
  }
}
```

### Zero-Rated Catalog Sync Flow

```
App launch (or 22-24h since last sync):
│
├─ Check if internet available (try http://92.4.95.252/api/catalog/version, timeout 3s)
│   SUCCESS (has internet):
│     → GET /api/catalog/version → compare with local version
│     → If newer: GET /api/catalog/sync?since={localVersion}
│     → Merge titles + episodes + share_urls into encrypted local DB
│     → Update sync timestamp
│
│   FAIL (no internet / timeout — Jazz SIM user with no bundle):
│     → Check JazzDrive db_update.json (ZERO-RATED)
│     → GET https://cloud.jazzdrive.com.pk/[db_update_file_share_url]
│     → Parse JSON → merge new titles/episodes/share_urls into encrypted DB
│     → Update sync timestamp
│
└─ Either way: app catalog now up to date
```

**`db_update.json` on JazzDrive** — generated by admin panel:
```json
{
  "version": 1748200000,
  "generated_at": "2026-05-25T18:00:00Z",
  "titles": [
    {
      "id": 4,
      "title": "Interstellar",
      "year": 2014,
      "media_type": "movie",
      "is_free": 1,
      "poster_url": "https://image.tmdb.org/t/p/w500/...",
      "share_url": "https://cloud.jazzdrive.com.pk/share/f/...",
      "file_id": 11
    }
  ],
  "episodes": [
    {
      "id": 33,
      "title_id": 17,
      "file_id": "33",
      "season": 1,
      "episode": 2,
      "label": "S01E02",
      "share_url": "https://cloud.jazzdrive.com.pk/share/f/..."
    }
  ]
}
```

**Update JazzDrive JSON file:** Admin clicks "Generate DB Update" in Radd Hub → downloads JSON → uploads to JazzDrive → all Jazz SIM users get update within 24h, zero-rated.

---

## Stream Link Cache — Full Rules

```
Storage: encrypted SQLite table `stream_cache`
  file_id     TEXT PRIMARY KEY
  stream_url  TEXT NOT NULL
  poster_url  TEXT
  created_at  INTEGER  (unix timestamp)
  expires_at  INTEGER  (created_at + 6 hours)

Rules:
  - Check cache FIRST before any network call
  - If expires_at > now() → use cached URL (no network, instant play)
  - If expires_at <= now() → generate new link (2 JazzDrive API calls)
  - Watch + download use SAME cached link (never generate twice for same file)
  - On generate: save to both in-memory map AND encrypted SQLite
  - On app start: load non-expired rows from SQLite into memory map
  - Expired rows: clean up once per day (lazy cleanup on app start)
```

---

## What Does NOT Change

- Authentication flow (JWT, login, register) — unchanged
- Catalog browse/search — unchanged  
- Subscription gating — unchanged (is_free check still happens)
- Admin panel — unchanged
- Oracle server still used for: login, catalog sync (when internet), subscription, history
- Oracle server NO LONGER used for: stream link generation, poster fetching

---

## Implementation Order

1. **Fix `_openMedia` bug** (player_screen.dart:223) — stop passing JSON endpoint to media_kit
2. **Build `JazzDriveService.dart`** — on-device link generation with 6h cache
3. **Add `share_url` to catalog sync** — backend + local DB schema (version 10)
4. **Wire player to use `JazzDriveService`** — replace `_openMedia` broken call
5. **Build `PosterService.dart`** — hidden folder, priority chain, background sync
6. **Encrypted DB** — replace sqflite with sqflite_sqlcipher + Keystore key
7. **Zero-rated catalog sync** — JazzDrive fallback when no internet
8. **Test on real Jazz SIM with data bundle OFF** — confirm fully zero-rated

---

## Files to Create / Modify

| Action | File |
|--------|------|
| CREATE | `lib/core/services/jazzdrive_service.dart` |
| CREATE | `lib/core/services/poster_service.dart` |
| CREATE | `lib/core/db/secure_db.dart` |
| MODIFY | `lib/screens/player_screen.dart` (fix _openMedia) |
| MODIFY | `lib/core/db/local_db.dart` (add share_url, version 10) |
| MODIFY | `lib/core/db/sync_service.dart` (zero-rated fallback) |
| MODIFY | `pubspec.yaml` (add sqflite_sqlcipher, http) |
| MODIFY | `_watch_prototype/routes/app_catalog.py` (add share_url to sync) |

