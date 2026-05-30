---
name: RaddFlix DB Migration Rules
description: Critical rules for SQLite schema changes, sqflite version pin, and key architectural facts
---

## _migrate Parameter Name
`_migrate(Database db, int oldV, int newV)` — parameter MUST be `oldV` not `oldVersion`.
Using `oldVersion` = compile error. Broke CI twice (commits 54660441, f571b352). Fixed in 5bd1ac75.

**Why:** The function signature in local_db.dart uses `oldV`. Comments use `oldVersion`. AI agents confused the two.
**How to apply:** Every `if (oldV < N)` block inside `_migrate` must use `oldV`.

## sqflite_sqlcipher Version Lock
Must stay at exactly `3.1.0+1` in pubspec.yaml (no caret).
- 3.2.0 breaks Gradle on Flutter 3.22 CI (`flutter.compileSdkVersion` not found in LibraryExtension)
- 3.2.1+ requires Flutter >=3.27.0 (current CI is 3.22)

**Why:** Pinned after CI broke, diagnosed by querying pub.dev API for all versions.
**How to apply:** Do not upgrade until CI is on Flutter 3.27+.

## Current DB Version
catalogDbVersion = 13 (as of 2026-05-30)
| v12 | show_ep_seen, stream_cache |
| v13 | catalog_fts (FTS5 virtual table) |
Next version when adding tables: 14, add `if (oldV < 14)` block.

## ON CONFLICT Compatibility
`ON CONFLICT(id) DO UPDATE SET...` requires SQLite 3.24+. Android 8 ships 3.19-3.22.
Check minSdk in android/app/build.gradle before using this syntax.
If minSdk < 26 (Android 8.0), use `INSERT OR REPLACE INTO` instead.

## CODE_MAP Location
agent-hub/CODE_MAP.md (914 lines) — maps every file to purpose/functions/known bugs.
Read before touching any source file. Fetch with:
`curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/agent-hub/CODE_MAP.md"`

## media_type Normalization (BUG-A02)
Server must return "show" for TV series in delta JSON.
Flutter filters: `item.mediaType == 'show'`
Server currently returns: "tv" or "series" -> TV shows invisible.
Fix in library.py: normalize before delta output.

## GitHub Commit Pattern
blob->tree->commit->PATCH ref.
For large files (base64 encoded content > ~50KB): use Python urllib, not curl -d (shell arg size limit).
Always `"force": false` in PATCH call. Never force-push.
