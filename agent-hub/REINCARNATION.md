# RaddFlix Agent Reincarnation — Rule 0

> **This is Rule 0. It runs before every other rule.**
> Every new agent session must complete this checklist before touching any code.

---

## Reincarnation Checklist (do all 4 steps, in order)

### Step 1 — Read the context files (5 min)
```
agent-hub/PRODUCT_CONTEXT.md         ← full product, architecture, all decisions
agent-hub/MASTER_TASKLIST.md         ← every task, status (✅/🔧/⬜), what to do next
agent-hub/STREAMING_ARCHITECTURE.md  ← streaming rules (IMMUTABLE)
agent-hub/history/TASK_LOG.md        ← what each previous session did (most recent = bottom)
```

### Step 2 — Run install script
```bash
curl -sL https://raw.githubusercontent.com/raddclub/raddflix-app/main/agent-hub/scripts/install.sh | bash
```
(SSH to Oracle will likely timeout from Replit — that is normal and not blocking.)

### Step 3 — Check CI status
```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/actions/runs?per_page=3" \
  | jq -r '.workflow_runs[] | "\(.status) \(.conclusion) \(.created_at[0:10]) \(.head_commit.message | split("\n")[0])"'
```
If the latest build is failing, **fix it before doing anything else**.

### Step 4 — Confirm your task
Tell the user:
- What the last session did (from TASK_LOG.md)
- What the next recommended tasks are (from MASTER_TASKLIST.md)
- Ask what they want to work on today

---

## Core Rules (never violate)

1. **NEVER add a server-side stream URL resolver.** Stream URLs come from local SQLite → JazzDrive only. See STREAMING_ARCHITECTURE.md.
2. **NEVER delete /opt/jazzmax/radd-hub/hub/_legacy/** — scanner.py imports from there.
3. **NEVER force-push to GitHub** — use `"force": false` in PATCH calls.
4. **NEVER write JazzMAX or Zeno** — app is RaddFlix (capital R, capital F).
5. **NEVER put JazzDrive share folder URLs in the delta JSON** — metadata only.
6. **ALWAYS update MASTER_TASKLIST.md** when you complete or discover tasks.
7. **ALWAYS append to TASK_LOG.md** at the end of your session (Rule 8 in SKILLS.md).

---

## The Most Important Facts (memorize these)

```
1. Video is served from JazzDrive CDN — not the RaddFlix server.
2. The app generates stream/download links LOCALLY from SQLite — no server call.
3. The most critical secret is the JazzDrive share folder URL stored in SQLite.
4. Zero-rating works because JazzDrive is zero-rated by Jazz Telecom.
5. Oracle SSH is unreachable from Replit — use GitHub API for all file operations.
6. jq 1.7.1 is available. For large files: write payload to disk with node, then POST.
7. AppConstants.supportWhatsApp = '923XXXXXXXXX' — still a placeholder pre-launch.
```

---

## What the App Does (30-second summary for any AI)

RaddFlix is a Pakistani streaming app. Jazz SIM users watch movies/dramas for free (zero-rated via JazzDrive). There's no Netflix-style server for video — everything streams from JazzDrive. Plans are data-based (30GB/50GB/100GB per month), not quality-based. The admin manages content through Radd Hub (Flask panel). The Flutter app has local SQLite with full catalog + JazzDrive share folder URLs, a 3400-line MX-Player-style video player, and various features for Pakistani users (Urdu subtitles, Hindi audio auto-select, etc.).

