# JazzMAX — Account Handoff Guide
> This file is for Muhammad Rehan when switching to a new Replit account.

---

## STEP 1 — SAVE YOUR WORK (on the CURRENT account before leaving)

Open the Replit Shell and run:
```bash
bash push_to_github.sh
```

This pushes everything to **github.com/raddclub/jazzmax-app** (private repo).
If it says "nothing to commit" and pushes — perfect. Move to Step 2.

---

## STEP 2 — SETUP ON THE NEW REPLIT ACCOUNT

### A. Create a new Repl
- Go to replit.com → Create Repl → choose any type (Python, Node, doesn't matter)
- Name it: `jazzmax`

### B. Add Secrets first (Replit sidebar → lock icon 🔒)

| Secret Name | Value |
|---|---|
| `GITHUB_TOKEN` | *(your GitHub personal access token with repo access)* |
| `SESSION_SECRET` | *(same value you always use — it's in your notes)* |

### C. Run ONE command in Shell — does everything automatically

```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://raw.githubusercontent.com/raddclub/jazzmax-app/main/setup_new_account.sh" \
  | bash
```

This script automatically:
- ✅ Downloads the full project from GitHub (bypasses git history conflict)
- ✅ Extracts all files safely (never overwrites Replit system files)
- ✅ Installs Python packages (flask, pyjwt, etc.)
- ✅ Tells you exactly what to do next

### D. Create workflows — tell the Replit Agent this exact message:

```
Set up the Radd Hub and Watch Prototype workflows
```

The agent creates both workflows automatically. When they go green — setup is done.

---

## STEP 3 — CONTINUE BUILDING

Type this as your first message to the agent:

```
I am Muhammad Rehan. Read JAZZMAX_MASTER.md first, then continue from
where we left off — find the first unchecked [ ] task in Section 14
of JAZZMAX_MASTER.md and build it.
```

---

## IF GITHUB PUSH FAILS — ZIP BACKUP METHOD

On the current account run:
```bash
bash create_zip.sh
```

Download `jazzmax_YYYYMMDD_HHMM.zip` from the Files panel → upload to new account.

In Shell on the new account:
```bash
python3 -c "
import zipfile
zf = zipfile.ZipFile('jazzmax_YYYYMMDD_HHMM.zip')
zf.extractall('.')
print('Done!')
"
pip install flask flask-cors pyjwt werkzeug requests
```

Then tell the agent: `Set up the Radd Hub and Watch Prototype workflows`

---

## QUICK REFERENCE — Workflows

| Workflow Name | Command | Port |
|---|---|---|
| `Radd Hub` | `cd radd-hub && python3 radd_hub.py run --skip-setup` | 5000 |
| `Watch Prototype` | `cd _watch_prototype && PORT=8000 python run.py` | 8000 |

---

## QUICK REFERENCE — Key Files

| File | Purpose |
|---|---|
| `JAZZMAX_MASTER.md` | Full project plan + task checklist — read first always |
| `setup_new_account.sh` | Run on new account to restore from GitHub automatically |
| `push_to_github.sh` | End of session: saves code to GitHub |
| `create_zip.sh` | Backup: creates zip if GitHub push fails |
| `_watch_prototype/run.py` | Watch API Flask app — all API routes |
| `_watch_prototype/routes/app_auth.py` | Auth API |
| `_watch_prototype/routes/app_catalog.py` | Catalog API |
| `_watch_prototype/routes/app_subscription.py` | Subscription + TID payment API |
| `radd-hub/hub/app.py` | Radd Hub admin — TID panel at /tid/ |
| `radd-hub/data/radd_hub.db` | SQLite database — DO NOT DELETE |

---

## QUICK REFERENCE — Payment Info

- **JazzCash / Easypaisa:** 03286839827 (Muhammad Rehan)
- TID flow: user pays on Jazz app → enters TID → admin verifies in Radd Hub at `/tid/`

---

## PROJECT PHASES

| Phase | What | Status |
|---|---|---|
| Phase 0 | Backend APIs (auth, catalog, subscription, TID panel) | ✅ Complete |
| Phase 1 | Flutter scaffold + GitHub Actions APK build | ⬜ Next |
| Phase 2 | Auth screens (login, register, splash) | ⬜ |
| Phase 3 | Home screen + catalog sync + poster grid | ⬜ |
| Phase 4 | Video player + JazzDrive streaming | ⬜ |
| Phase 5 | Subscription flow + TID payment UI | ⬜ |
| Phase 6 | Polish, offline mode, downloads | ⬜ |
