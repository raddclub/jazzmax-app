# RaddFlix — Agent Hub

> **If you are an AI agent, read this entire file before doing anything.**
> Then read `TASK_LOG.md` to see what has already been done.
> Then follow `SKILLS.md` rules strictly.

---

## What is RaddFlix?

RaddFlix is a Pakistani streaming platform. Jazz SIM users stream movies/dramas for free (zero-rated via JazzDrive CDN). There is a Flutter mobile app, a Flask admin panel, and a WhatsApp bot in development.

**Previous names (do not use these anywhere):** JazzMAX, Zeno

---

## Infrastructure at a Glance

### Oracle Server
- **IP:** `92.4.95.252`
- **User:** `ubuntu`
- **SSH key:** stored in `ORACLE_SSH_KEY` env var (base64-encoded, may have spaces — remove them when decoding)
- **Project root:** `/opt/jazzmax/` (folder name is legacy, do not rename it)

### Services (managed by Supervisor)
| Supervisor name | What it does | Port | Start/stop command |
|----------------|-------------|------|-------------------|
| `jazzmax_radd` | Flask admin panel (Radd Hub v3.0) | 5000 | `sudo supervisorctl restart jazzmax_radd` |
| `jazzmax_watch` | Mobile watch API | 6000 | `sudo supervisorctl restart jazzmax_watch` |

### GitHub
- **Repo:** `raddclub/raddflix-app`
- **Token:** stored in `GITHUB_TOKEN` env var
- **Branch:** `main`
- **IMPORTANT:** Never force-push. Always use GitHub API tree commits (not git commands) when editing from Replit.

---

## Server Folder Map

```
/opt/jazzmax/
├── radd-hub/                  ← Flask admin panel
│   ├── hub/
│   │   ├── app.py             ← Flask app entry point
│   │   ├── routes/            ← All API route blueprints (library, admin, stream, etc.)
│   │   ├── _legacy/           ← !! DO NOT DELETE !! jazzdrive.py + scanner.py import from here
│   │   └── templates/         ← Jinja2 HTML templates
│   └── requirements.txt
├── raddflix_flutter/           ← Flutter mobile app source (build on dev machine, not server)
├── _watch_prototype/          ← Early prototype, reference only
├── wa-bot/                    ← WhatsApp bot (Node.js)
└── scripts/                   ← Utility scripts
```

---

## CRITICAL: Things You Must Never Do

1. **Never delete `/opt/jazzmax/radd-hub/hub/_legacy/`** — jazzdrive.py and scanner.py import JazzDrive login/OTP/session from here. Deleting it breaks the entire streaming system.
2. **Never rename `/opt/jazzmax/`** — it's the server's production root. Renaming it breaks supervisor configs and all scripts.
3. **Never write JazzMAX or Zeno anywhere** — full rebrand to RaddFlix is complete.
4. **Never hardcode secrets** — always use `ORACLE_SSH_KEY` and `GITHUB_TOKEN` env vars.
5. **Never force-push to GitHub** — use `"force": False` in all PATCH calls.
6. **Always append to TASK_LOG.md after your work** — future agents depend on this.

---

## How to Start Working (30-second setup)

1. Make sure `GITHUB_TOKEN` and `ORACLE_SSH_KEY` are set in Replit Secrets
2. Run the install script: `curl -sL https://raw.githubusercontent.com/raddclub/raddflix-app/main/agent-hub/scripts/install.sh | bash`
3. Read `agent-hub/history/TASK_LOG.md` to see what has been done
4. Do your work
5. Append your summary to `TASK_LOG.md` via GitHub API

---

## Projects — Quick Reference

| Project | Doc | Key tech |
|---------|-----|---------|
| Admin panel (Radd Hub) | `projects/radd-hub.md` | Python 3.12, Flask, SQLite, Supervisor |
| Flutter mobile app | `projects/flutter-app.md` | Flutter/Dart, Dio, SQLite, FCM |
| WhatsApp bot | `projects/wa-bot.md` | Node.js 20, wa-web.js |

---

## Paste This Prompt When Starting a New Agent Session

See `PROMPT.md` for the exact ready-to-paste prompt.
