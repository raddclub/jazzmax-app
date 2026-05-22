# JazzMAX — Replit Account Handoff Guide

> **Read this completely before starting.** Following these steps in order prevents every error.

---

## BEFORE YOU LEAVE THE OLD ACCOUNT

Run this in Shell to save everything to GitHub:

```bash
bash push_to_github.sh
```

Wait for `✅ DONE!` — then close the old account.

---

## SETTING UP ON THE NEW REPLIT ACCOUNT

### STEP 1 — Add Secrets (do this FIRST, before anything else)

Go to: **Replit sidebar → Secrets (🔒 lock icon) → + Add Secret**

| Secret Name | What to put |
|---|---|
| `GITHUB_TOKEN` | Your GitHub Personal Access Token (needs `repo` permission) |
| `SESSION_SECRET` | The Flask secret key (same value always — check your notes) |

> ⚠️ If you skip this step, the setup script will fail immediately.

---

### STEP 2 — Pull the project from GitHub

**Open Shell** and run this ONE command:

```bash
curl -fsSL \
  -H "Authorization: token $GITHUB_TOKEN" \
  "https://raw.githubusercontent.com/raddclub/jazzmax-app/main/setup_new_account.sh" \
  | bash
```

This takes 1–3 minutes. It will:
- ✅ Verify your GitHub token works
- ✅ Download the full project from GitHub
- ✅ Extract all files including `.replit` (which defines both workflows)
- ✅ Install all Python packages from `requirements.txt`
- ✅ Tell you exactly what to do next

---

### STEP 3 — Reload Replit so workflows appear

After the script finishes, **click the browser Refresh button (F5)**.

You should now see in the Run button dropdown:
- **Radd Hub** (port 5000 — admin backend)
- **Watch Prototype** (port 8000 — app API)

Click **Run** → both start automatically.

> If workflows do NOT appear after refresh, tell the Replit Agent:
> `"Create a Radd Hub workflow: cd radd-hub && python3 radd_hub.py run --skip-setup (port 5000) and a Watch Prototype workflow: cd _watch_prototype && PORT=8000 python3 run.py (port 8000)"`

---

### STEP 4 — Verify both services are running

Open the workflow consoles and confirm:
- **Radd Hub** → `Running on http://0.0.0.0:5000`
- **Watch Prototype** → `Running on http://0.0.0.0:8000`

If either fails, see **Troubleshooting** below.

---

### STEP 5 — Update the server URL in the Flutter app

The app reads its server URL from a file in GitHub. Edit:

📄 **`jazzmax_config.json`** (in the project root)

```json
{
  "_note": "Update api_base_url when moving servers — no app rebuild needed!",
  "api_base_url": "https://YOUR-NEW-REPLIT-DEV-DOMAIN.replit.dev",
  "updated_at": "2026-05-23"
}
```

To find your dev domain: click the **Open in new tab** icon on the Watch Prototype workflow → copy the URL.

Then push to GitHub:
```bash
bash push_to_github.sh
```

All installed apps pick up the new URL automatically on next launch — **no APK rebuild needed**.

---

### STEP 6 — Tell the agent to continue building

Type this as your first message to the Replit Agent:

```
I am Muhammad Rehan. Read JAZZMAX_MASTER.md Section 14 (Task Checklist),
find the first unchecked [ ] item, and build it.
```

---

## TROUBLESHOOTING

### "python3: command not found" or workflow won't start

The `.replit` file includes `modules = ["python-3.11"]` so Python should be available automatically. If not, tell the Agent:

```
Install Python 3.11 and pip, then restart the Radd Hub and Watch Prototype workflows.
```

Or in Shell:
```bash
pip3 install -r requirements.txt -q
```

### "Cannot connect to server" in the Flutter app

The app is pointing at the wrong URL. Update `jazzmax_config.json` → push to GitHub (Step 5).

### "GITHUB_TOKEN not set" error

You missed Step 1. Add the secret in Replit sidebar (🔒 lock icon), then re-run the setup command from Step 2.

### Workflows exist but crash immediately on start

Check the workflow console for errors. Common fix:
```bash
pip3 install -r requirements.txt -q
```
Then click **Restart** on the workflow.

### "Database not found" or SQLite errors

The DB creates itself on first run. Just restart both workflows — first startup initializes everything automatically.

### Setup script fails during extraction

Node.js may not be ready yet. Wait 30 seconds and re-run. Or extract manually:
```bash
cd /tmp && npm install adm-zip --save --silent 2>/dev/null
cd /home/runner/workspace
node -e "
const AdmZip = require('/tmp/node_modules/adm-zip');
const fs = require('fs'), path = require('path');
const zip = new AdmZip('/tmp/jazzmax_github.zip');
const entries = zip.getEntries();
const prefix = entries[0].entryName.split('/')[0] + '/';
let n = 0;
for (const e of entries) {
  const rel = e.entryName.slice(prefix.length);
  if (!rel || e.isDirectory) continue;
  const dest = '/home/runner/workspace/' + rel;
  fs.mkdirSync(path.dirname(dest), {recursive:true});
  fs.writeFileSync(dest, e.getData());
  n++;
}
console.log('Extracted', n, 'files');
"
pip3 install -r requirements.txt -q
```

---

## QUICK REFERENCE

### Workflow Commands

| Workflow | Command | Port |
|---|---|---|
| Radd Hub | `cd radd-hub && python3 radd_hub.py run --skip-setup` | 5000 |
| Watch Prototype | `cd _watch_prototype && PORT=8000 python3 run.py` | 8000 |

### Key Files

| File | Purpose |
|---|---|
| `jazzmax_config.json` | **App server URL** — edit this when switching servers |
| `JAZZMAX_MASTER.md` | Full spec + Section 14 task checklist |
| `requirements.txt` | All Python packages |
| `radd-hub/data/radd_hub.db` | SQLite database (shared by both services) |
| `push_to_github.sh` | Run at end of every session to save work |
| `setup_new_account.sh` | Run on any new Replit account to restore everything |

### Secrets Required on Every Account

| Secret | Used by |
|---|---|
| `GITHUB_TOKEN` | push_to_github.sh, setup_new_account.sh, GitHub Actions APK build |
| `SESSION_SECRET` | Flask sessions + JWT signing |

### GitHub Actions APK Build

Every push to `main` auto-builds a signed release APK.
Download: **GitHub → raddclub/jazzmax-app → Actions → latest ✅ run → Artifacts**

The APK reads server URL from `jazzmax_config.json` — **no rebuild needed to switch servers**.

### Guest Mode (live in app)

- "Continue as Guest" button on Login and Register screens
- Backend issues a 24-hour token via `POST /api/auth/guest`
- Player pauses at exactly 10 minutes and shows a subscribe popup
- Popup options: Subscribe Now / Create Account / Back to Home

---

## MOVING TO ORACLE UBUNTU (future)

1. On Ubuntu: `sudo apt install python3 python3-pip git`
2. `git clone https://github.com/raddclub/jazzmax-app.git`
3. `pip3 install -r requirements.txt`
4. Start Radd Hub: `cd radd-hub && python3 radd_hub.py run --skip-setup`
5. Start Watch Prototype: `cd _watch_prototype && PORT=8000 python3 run.py`
6. Point your domain at the server IP
7. Edit `jazzmax_config.json` → set `api_base_url` to `https://yourdomain.com` → `bash push_to_github.sh`
8. All installed apps switch automatically — no APK rebuild ever needed

---

*Last updated: 2026-05-23*
