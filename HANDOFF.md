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
| `ORACLE_SSH_KEY` | Full private SSH key (including `-----BEGIN...` and `-----END...` lines) |

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

### STEP 6 — Restore Oracle SSH key each session

**Every new session**, run this in Shell to write the SSH key properly:

```bash
python3 -c "
import os
key = os.environ.get('ORACLE_SSH_KEY','')
key = key.replace(' ', '\n')
# Fix header/footer
import re
key = re.sub(r'-----BEGIN\nRSA\nPRIVATE\nKEY-----', '-----BEGIN RSA PRIVATE KEY-----', key)
key = re.sub(r'-----END\nRSA\nPRIVATE\nKEY-----', '-----END RSA PRIVATE KEY-----', key)
with open('/tmp/oracle_key_fixed','w') as f: f.write(key+'\n')
os.chmod('/tmp/oracle_key_fixed', 0o600)
print('Key written OK')
"
# Test it works:
ssh -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@92.4.95.252 "echo OK"
```

---

### STEP 7 — Tell the agent to continue building

Type this as your first message to the Replit Agent:

```
I am Muhammad Rehan. Read JAZZMAX_MASTER.md Section 14 (Task Checklist),
find the first unchecked [ ] item, and build it.
```

---

## ORACLE SERVER — KEY INFO

| Item | Value |
|---|---|
| IP | `92.4.95.252` |
| User | `ubuntu` |
| SSH key | In `ORACLE_SSH_KEY` secret (write to `/tmp/oracle_key_fixed` each session) |
| Radd Hub URL | `http://92.4.95.252:5000` |
| Radd Hub login | `admin` / `6LQRmtOM5d1PETSI` |
| Radd Hub DB | `/opt/jazzmax/radd-hub/data/radd_hub.db` |
| Service manager | `sudo supervisorctl status/restart jazzmax_radd` |
| Error log | `/var/log/jazzmax_radd.err.log` |
| JazzDrive account | id=27, msisdn=03029688227, role=flix (active as of 2026-05-23) |

**Deploy code changes to Oracle:**
```bash
scp -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no \
  radd-hub/hub/_legacy/scanner.py \
  ubuntu@92.4.95.252:/opt/jazzmax/radd-hub/hub/_legacy/scanner.py

scp -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no \
  radd-hub/hub/uploader.py \
  ubuntu@92.4.95.252:/opt/jazzmax/radd-hub/hub/uploader.py

scp -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no \
  radd-hub/hub/routes/upload.py \
  ubuntu@92.4.95.252:/opt/jazzmax/radd-hub/hub/routes/upload.py

ssh -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no ubuntu@92.4.95.252 \
  "sudo supervisorctl restart jazzmax_radd"
```

---

## CURRENT STATE (as of 2026-05-23 Session 6)

### ✅ JazzDrive Session ACTIVE
- Account id=27, msisdn=03029688227, role=flix
- JSESSIONID saved, logged_in=True
- token_expires_at=1782163040 (~June 20 2026)

### ⏳ Downloads Queued & Running on Oracle
All 5 items were queued and CDN resolution is actively happening:

| Content | Job ID | Status |
|---|---|---|
| The Boys S5 | 93282e3298 | queued/running |
| Mirzapur S2 | e296b7d179 | queued/running |
| Salaar | a69a299af8 | queued/running |
| Pathaan | 8d2ecd6d1f | queued/running |
| Fast & Furious 5 | 2d346a06fc | queued/running |

**Monitor at:** `http://92.4.95.252:5000/stream/`

### 🐛 Bugs Fixed This Session
1. **`_legacy/scanner.py`** — OTP login now extracts JSESSIONID from OAuth redirect chain cookies BEFORE clearing them (and tries fetching `clientoauth.html` explicitly). This bypasses the geo-restricted SAPI silent-login endpoint that was blocking all non-PK IPs.
2. **`uploader.py`** — Removed `AND validation_key!=''` from `get_active_account()` query — `validation_key` is optional, JSESSIONID alone is enough.
3. **`routes/upload.py`** — `logged_in` check now only requires `jsessionid` (not `vk`). Added `/api/jazzdrive/tokens` endpoint for manual cookie paste.

### 📱 App Current State
- 14 titles, 30 files in library
- APK build auto-runs on every GitHub push

---

## NEXT SESSION — WHAT TO DO

### 1. Write the SSH key (every session)
Run the Step 6 script above.

### 2. Check download progress
```bash
ssh -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no ubuntu@92.4.95.252 '
curl -s -c /tmp/c.txt -X POST -d "username=admin&password=6LQRmtOM5d1PETSI" http://localhost:5000/auth/login -L > /dev/null
curl -s -b /tmp/c.txt http://localhost:5000/stream/api/queue
'
```
Or open `http://92.4.95.252:5000/stream/` in your browser.

### 3. After downloads finish → Add to JazzMAX app DB
Once files are uploaded to JazzDrive, the agent needs to add them to the Watch Prototype database so they appear in the app. Tell the agent:
```
Check the Radd Hub library at http://92.4.95.252:5000/upload/api/library
and add any new JazzDrive files to the JazzMAX app database.
```

### 4. For Mirzapur S2 and The Boys S5 — verify zip
These seasons should be downloaded as zipped episodes. Confirm in the stream queue that they were zipped.

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

### OTP login gives "needs_paste_cookies" error again

This was a bug that has been fixed (Session 6). If it reappears, make sure the latest code is deployed to Oracle:
```bash
# Deploy the fix
scp -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no \
  radd-hub/hub/_legacy/scanner.py \
  ubuntu@92.4.95.252:/opt/jazzmax/radd-hub/hub/_legacy/scanner.py
ssh -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no ubuntu@92.4.95.252 \
  "sudo supervisorctl restart jazzmax_radd"
```

### JazzDrive session expired (logged_in=False after restart)

The session is valid until ~June 20 2026. If it expires:
1. Open `http://92.4.95.252:5000/upload/` in browser
2. Send OTP to 03029688227
3. Enter the code — it will now work (bug is fixed)

### SQLite WAL corruption on Oracle
```bash
ssh -i /tmp/oracle_key_fixed ubuntu@92.4.95.252 "
sudo supervisorctl stop jazzmax_radd
sqlite3 /opt/jazzmax/radd-hub/data/radd_hub.db 'PRAGMA wal_checkpoint(TRUNCATE);'
rm -f /opt/jazzmax/radd-hub/data/radd_hub.db-wal /opt/jazzmax/radd-hub/data/radd_hub.db-shm
sudo supervisorctl start jazzmax_radd
"
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
| `radd-hub/data/radd_hub.db` | SQLite database (Replit local copy) |
| `/opt/jazzmax/radd-hub/data/radd_hub.db` | SQLite database (Oracle — the live one) |
| `push_to_github.sh` | Run at end of every session to save work |
| `setup_new_account.sh` | Run on any new Replit account to restore everything |
| `radd-hub/hub/_legacy/scanner.py` | OTP/login flow — fixed in Session 6 |
| `radd-hub/hub/uploader.py` | JazzDrive upload logic + get_active_account() |
| `radd-hub/hub/routes/upload.py` | Upload API routes including jd-stats |

### Secrets Required on Every Account

| Secret | Used by |
|---|---|
| `GITHUB_TOKEN` | push_to_github.sh, setup_new_account.sh, GitHub Actions APK build |
| `SESSION_SECRET` | Flask sessions + JWT signing |
| `ORACLE_SSH_KEY` | SSH access to Oracle Ubuntu (92.4.95.252) |

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

*Last updated: 2026-05-23 (Session 6)*
