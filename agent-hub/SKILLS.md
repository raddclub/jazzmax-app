# RaddFlix Agent Skills & Rules

> These rules are non-negotiable. Every agent working on RaddFlix must follow them exactly.
> Violating these rules can break production for real users.

---

## Rule 1 — Read Before You Touch

Before making any change:
1. Read `agent-hub/history/TASK_LOG.md` — know what was already done
2. Read the relevant project doc in `agent-hub/projects/`
3. If touching the server, SSH in and `cat` the file before editing it

Never assume a file's content. Always read it first.

---

## Rule 2 — SSH Connection Pattern

Write the key directly to a file (it is stored as plain text in Replit Secrets):

```bash
printf '%s' "$ORACLE_SSH_KEY" > /tmp/oracle_key && chmod 600 /tmp/oracle_key
ssh -i /tmp/oracle_key -o StrictHostKeyChecking=no ubuntu@92.4.95.252 "your command"
```

Test the connection before doing anything:
```bash
ssh -i /tmp/oracle_key -o StrictHostKeyChecking=no ubuntu@92.4.95.252 "echo OK"
```

---

## Rule 3 — GitHub API Pattern

Always use the GitHub tree API for multi-file commits. Never use `git` shell commands from Replit.

```python
# Pattern for uploading changed files:
# 1. GET /repos/raddclub/raddflix-app/git/ref/heads/main  → head_sha
# 2. GET /repos/raddclub/raddflix-app/git/trees/{head_sha}?recursive=1  → existing tree
# 3. POST /repos/raddclub/raddflix-app/git/blobs  → upload each new file content
# 4. POST /repos/raddflix/raddflix-app/git/trees  → new tree (keep existing, swap changed)
# 5. POST /repos/raddclub/raddflix-app/git/commits  → new commit
# 6. PATCH /repos/raddclub/raddflix-app/git/refs/heads/main  → move branch (force: False)
```

Always use `"force": False` in the PATCH call. Never force-push.

---

## Rule 4 — Server Edit Pattern

For editing server files:
1. Always `cat` the file first via SSH before editing
2. Use Python `str.replace()` — never regex unless necessary
3. Verify the change after writing: `grep` for the new string
4. Restart the relevant supervisor service if you changed Python files
5. Check service status: `sudo supervisorctl status`

---

## Rule 5 — Supervisor Service Management

```bash
# Check status
sudo supervisorctl status

# Restart after Python file changes
sudo supervisorctl restart jazzmax_radd   # admin panel (port 5000)
sudo supervisorctl restart jazzmax_watch  # watch API (port 6000)

# Check logs if something is wrong
sudo supervisorctl tail -f jazzmax_radd
```

Always verify services are RUNNING after any server-side change.

---

## Rule 6 — Never Touch These

| Path | Why |
|------|-----|
| `/opt/jazzmax/radd-hub/hub/_legacy/` | jazzdrive.py + scanner.py import from here. Deleting = broken streaming. |
| `/opt/jazzmax/` (the folder itself) | Production root. Supervisor configs point here. |
| `main` branch with force push | Will corrupt git history |

---

## Rule 7 — Naming & Branding

- App name: **RaddFlix** (capital R, capital F)
- Package ID: `com.raddflix.app`
- Old names that must never appear: `JazzMAX`, `jazzmax` (except internal server folder paths), `Zeno`, `zeno`
- Exception: `JazzDrive` is Jazz Telecom's CDN product — this name is correct and should stay

---

## Rule 8 — Task Log Update (Required After Every Session)

After completing your work, append to `agent-hub/history/TASK_LOG.md` via GitHub API.

Format:
```
## [YYYY-MM-DD HH:MM UTC] — Agent: <Replit account or description>

### Task
Brief description of what you were asked to do.

### Done
- Item 1
- Item 2

### Files Changed
- `path/to/file.py` — what changed
- `path/to/other.dart` — what changed

### Notes for Next Agent
Anything the next agent should know. Warnings, incomplete items, etc.

---
```

---

## Rule 9 — Secrets Handling

- `GITHUB_TOKEN` — GitHub personal access token (raddclub account)
- `ORACLE_SSH_KEY` — SSH private key pasted as plain text from Oracle (no encoding)
- Never print secrets to console
- Never write secrets into any file that gets committed to GitHub
- Never hardcode IP, passwords, or keys anywhere in code

---

## Rule 10 — Verify, Don't Assume

After every change:
- Server change → SSH in and confirm the new content is there
- GitHub change → verify commit SHA was returned successfully
- Service restart → run `sudo supervisorctl status` and confirm RUNNING
- Dart/Flutter change → grep to confirm old string is gone and new string is present

If something looks wrong, fix it before logging it as done.


  ---

  ## Addendum — Confirmed Working Tools (2026-05-28)

  ### jq is Available
  `jq` (v1.7.1) is available in the Replit bash environment. Use it to parse GitHub API JSON responses:

  ```bash
  # Get HEAD SHA
  HEAD_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/raddclub/raddflix-app/git/refs/heads/main" \
    | jq -r '.object.sha')

  # Get tree SHA from commit
  TREE_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/raddclub/raddflix-app/git/commits/$HEAD_SHA" \
    | jq -r '.tree.sha')
  ```

  ### Support WhatsApp Constant
  All WhatsApp deep links in the app use `AppConstants.supportWhatsApp` (defined in `raddflix_flutter/lib/core/constants.dart`).
  Before production release, update this constant to the real support phone number (international format, no +, no spaces, e.g. `923001234567`).

  Current value: `'923XXXXXXXXX'` (placeholder).

  ---

  ## Addendum — Metadata Fallback Chain (2026-05-29)

  ### Full 6-Tier Enrichment Order

  Both `metadata_lookup.py::enrich()` and `metadata.py::enrich_title()` now use this chain:

  | Tier | Source | Key needed? | Best for |
  |------|--------|------------|----------|
  | 1 | TMDB | Yes — vault provider `tmdb` | International movies & TV |
  | 2 | OMDB | Yes — vault provider `omdb` | IMDB ratings, older Western content |
  | 3 | AI (Groq/Gemini/OpenAI/OpenRouter) | Yes — vault `groq`/`gemini`/etc | Pakistani/Indian regional content |
  | 4 | IMDbAPI.dev | **No key needed** | Free IMDB data; Punjabi/South Asian |
  | 5 | YouTube | Optional — vault `youtube` (Data API v3); also scrapes HTML with no key | Trailer thumbnail as poster |
  | 6 | Google KG | Optional — vault provider `google` | Google Knowledge Graph name/overview |

  ### Adding Optional Keys to the Vault

  In RaddHub → Settings → API Keys:
  - `youtube` — YouTube Data API v3 key (Google Cloud Console → YouTube Data API v3)
  - `google` — Google API key with Knowledge Graph Search API enabled

  These are optional but improve poster quality for YouTube (higher-res thumbnails)
  and Google KG (structured metadata). Without them, YouTube falls back to HTML
  scraping and Google KG is skipped.

  ### Where the fallback chain runs
  - `metadata_lookup.py::enrich()` — called by scanner, post-scan enrichment
  - `metadata.py::enrich_title()` — called by legacy import + `_import_legacy_into_v3_for_account`
  - `organizer.py::enrich_title_metadata()` — helper for post-organize enrichment
  - `downloader.py` — triggers enrichment after every successful upload

  ### IMDbAPI.dev is always available (no key, no rate limit on reasonable usage)
  The free IMDB API at `imdbapi.dev` covers many Pakistani/Punjabi films not on TMDB+OMDB.
  It's particularly good for: Lollywood films, Pakistani TV dramas, Punjabi cinema.

