# RaddFlix Streaming Architecture — Source of Truth

> **Read this before touching anything related to streams, downloads, or catalog.**

---

## How Streaming & Downloads Work (CRITICAL)

### There is NO stream server. Everything is JazzDrive.

```
User's Phone (RaddFlix App)
        ↓
  Local SQLite DB  ←──── contains JazzDrive share folder URLs
        ↓
  App generates stream/download link LOCALLY (no server call)
        ↓
  JazzDrive CDN  ←──── video plays directly from here
```

- The RaddFlix server (92.4.95.252) does **NOT** serve video files
- The RaddFlix server does **NOT** store or proxy stream URLs
- The RaddFlix server does **NOT** get involved at playback time
- Stream and download links are generated **inside the app** from the local SQLite database
- The database contains JazzDrive share folder URLs — this is the source of all playback

### Why this matters
- Zero-rating works because JazzDrive is zero-rated by Jazz — not because of anything the server does
- Adding a "get stream URL from server" step would BREAK zero-rated playback
- Never add a server-side stream URL resolver — it is architecturally wrong for this product

---

## What the JazzDrive Share Folder URL is

```
Each title in SQLite has a JazzDrive share folder URL, e.g.:
  https://www.jazzdrive.com.pk/s/xxxxxxxx

App uses this URL to:
  1. List files in the folder (episodes, qualities)
  2. Generate direct stream links locally
  3. Generate download links locally

NO server involved. NO API call to 92.4.95.252 at this step.
```

---

## Security Priority

The **most important secret** in the whole system is the **JazzDrive share folder URL**.

If someone gets the share folder URL → they can stream and download without the app.

Protection strategy:
- Share folder URLs stored encrypted in SQLite (SQLCipher + Android Keystore)
- Delta JSON on JazzDrive contains metadata ONLY — no share folder URLs, no file IDs
- Full catalog never goes to JazzDrive
- Goal: make DB hard to decrypt — even root + any tool = only encrypted blob

---

## What IS on the RaddFlix Server

| Thing | On server? |
|-------|-----------|
| Video files | ❌ Never |
| Stream URLs | ❌ Never |
| Download links | ❌ Never |
| User accounts | ✅ Yes |
| Subscription plans | ✅ Yes |
| Data usage counters | ✅ Yes (synced from app) |
| Catalog metadata | ✅ Yes (source of truth) |
| Admin panel (Radd Hub) | ✅ Yes |

---

## Data Usage Tracking (no server at stream time)

```
Streaming (zero-rated, no internet bundle):
  → App counts bytes locally in encrypted SQLite
  → Queued usage report stored locally
  → When internet returns → app auto-syncs usage to server
  → Server updates authoritative counter

If user never gets internet:
  → App enforces LOCAL quota (last known balance from server)
  → When local quota hits 0 → streaming blocked
  → To unlock: must connect once (buy any bundle, even Rs.10)
  → Expired subscription auto-downgrades to free tier locally
```

---

## Subscription Plans (data-based, no quality tiers)

No 480p/720p/1080p limits. Plans are purely data volume:

| Plan | Data/month |
|------|-----------|
| Basic | 30 GB |
| Standard | 50 GB |
| Premium | 100 GB |
| Free tier | Limited catalog, limited data |

---

## Device Binding

- 1 account = 1 device
- Device fingerprint registered at first login
- Second device login → rejected
- Device switch → requires OTP + admin or self-service flow

---

## Zero-Rating Flow Summary

```
Has internet bundle → normal server sync + JazzDrive streaming
Rs.0 balance       → JazzDrive streaming (zero-rated) + local quota enforcement
Quota = 0          → all streaming blocked until server sync
Re-subscribe       → requires internet (any amount)
```

