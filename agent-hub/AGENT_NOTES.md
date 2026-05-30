# RaddFlix Agent Notes

## Agent Authority
The Replit agent is a **50% admin** on this project.

Full authority to: fix bugs, push to GitHub, run DB migrations, restart services, restore files, update docs.
**Never ask permission** for standard maintenance. Just do it.

---

## CRITICAL: `_legacy/` Python Files

`/opt/jazzmax/radd-hub/hub/_legacy/` — **8 Python files required for service startup.**

Without them: `jazzmax_radd` fails with `ImportError` → supervisor `spawn error`.

Files: `__init__.py`, `scanner.py`, `schema.py`, `enricher.py`, `jazz_share.py`, `jazz_keepalive.py`, `db_github.py`, `db_gsheets.py`

**They are now in GitHub** (restored 2026-05-30 commit `1a65f8c8`). A fresh `git pull` on the server will include them.

If ever missing again:
```bash
cd /opt/jazzmax && git pull && sudo supervisorctl restart jazzmax_radd
```

---

## Common Server Fixes

### Service won't start
```bash
sudo tail -30 /var/log/jazzmax_radd.err.log   # read the actual error
sudo supervisorctl status
```

### DB missing column (e.g. watched_at)
```bash
sqlite3 /opt/jazzmax/radd-hub/data/radd_hub.db '.schema <table>'
sqlite3 /opt/jazzmax/radd-hub/data/radd_hub.db 'ALTER TABLE <t> ADD COLUMN <col> <type> DEFAULT 0;'
sudo supervisorctl restart jazzmax_radd
```

### After git pull always restart
```bash
cd /opt/jazzmax && git pull && sudo supervisorctl restart jazzmax_radd
```

### SSH Key (Replit → Oracle)
`ORACLE_SSH_KEY` in Replit Secrets is stored with spaces not newlines. Reformat before use:
```python
raw = os.environ["ORACLE_SSH_KEY"].strip()
raw = raw.replace("-----BEGIN RSA PRIVATE KEY----- ", "-----BEGIN RSA PRIVATE KEY-----\n")
raw = raw.replace(" -----END RSA PRIVATE KEY-----", "\n-----END RSA PRIVATE KEY-----")
import textwrap
lines = raw.split("\n")
out = []
for line in lines:
    if line.startswith("-----"): out.append(line)
    else: out.extend(textwrap.wrap(line, 64))
open("/tmp/oracle_key","w").write("\n".join(out)+"\n")
import os; os.chmod("/tmp/oracle_key", 0o600)
```

---

## Known Bugs Fixed (2026-05-30)

| Bug | File | Fix |
|-----|------|-----|
| Hardcoded Replit path in `watch_dir` | `scraper.py:461` | Use `config.MEDIA_DIR` |
| Missing `watched_at` column | prod DB | `ALTER TABLE watch_history ADD COLUMN` |
| `_legacy/` files wiped by stash | server | Restored from git history + re-added to GitHub |
| Escaped quotes in f-string | `organizer.py:686` | Use temp variable for dict |
