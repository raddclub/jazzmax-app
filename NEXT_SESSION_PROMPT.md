# JazzMAX — Next Session Starter Prompt

**Copy everything below this line and paste it as your FIRST message to the agent.**

---

I am Muhammad Rehan. This is the JazzMAX project — an Android streaming app for Jazz SIM users in Pakistan (zero-rated via JazzDrive). Here is the full context from Session 6 so you can continue without wasting time:

## What Was Done This Session (Session 6)

### Bug Fixed: JazzDrive OTP Login
The "needs_paste_cookies" error was a code bug — not a JazzDrive IP block. The fix was in `radd-hub/hub/_legacy/scanner.py`: after OTP verification, the code was clearing `cloud.jazzdrive.com.pk` cookies BEFORE checking if JSESSIONID was already set by the OAuth redirect chain. Now it:
1. Checks for existing JSESSIONID in redirect-chain cookies first
2. If not there, fetches `clientoauth.html` explicitly to get them naturally
3. Only falls back to geo-restricted SAPI silent-login as last resort

Two more fixes in `uploader.py` and `routes/upload.py`: removed the `validation_key!=''` requirement — JSESSIONID alone is enough to operate.

### Current State RIGHT NOW
- **JazzDrive session: ACTIVE** on Oracle (92.4.95.252)
  - Account id=27, msisdn=03029688227, role=flix, logged_in=True
  - Token expires ~June 20 2026
- **5 downloads ACTIVELY RUNNING on Oracle:**
  - The Boys S5 (job: 93282e3298)
  - Mirzapur S2 (job: e296b7d179)
  - Salaar (job: a69a299af8)
  - Pathaan (job: 8d2ecd6d1f)
  - Fast & Furious 5 (job: 2d346a06fc)

## Oracle Server Details

- IP: `92.4.95.252`, user: `ubuntu`
- SSH key: in `ORACLE_SSH_KEY` secret — MUST write it to file at start of every session:

```bash
python3 -c "
import os, re
key = os.environ.get('ORACLE_SSH_KEY','')
key = key.replace(' ', '\n')
key = re.sub(r'-----BEGIN\nRSA\nPRIVATE\nKEY-----', '-----BEGIN RSA PRIVATE KEY-----', key)
key = re.sub(r'-----END\nRSA\nPRIVATE\nKEY-----', '-----END RSA PRIVATE KEY-----', key)
with open('/tmp/oracle_key_fixed','w') as f: f.write(key+'\n')
os.chmod('/tmp/oracle_key_fixed', 0o600)
print('Key written OK')
"
ssh -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@92.4.95.252 "echo connected OK"
```

- Radd Hub: `http://92.4.95.252:5000` (admin / 6LQRmtOM5d1PETSI)
- DB: `/opt/jazzmax/radd-hub/data/radd_hub.db`
- Supervisor: `sudo supervisorctl restart jazzmax_radd`
- Logs: `tail -f /var/log/jazzmax_radd.err.log`

## What To Do Now

### Step 1 — Write the SSH key (always first)
Run the python3 key script above.

### Step 2 — Check download progress
```bash
ssh -i /tmp/oracle_key_fixed -o StrictHostKeyChecking=no ubuntu@92.4.95.252 '
curl -s -c /tmp/c.txt -X POST -d "username=admin&password=6LQRmtOM5d1PETSI" http://localhost:5000/auth/login -L > /dev/null
curl -s -b /tmp/c.txt http://localhost:5000/stream/api/queue | python3 -c "
import sys,json
d=json.load(sys.stdin)
jobs=d if isinstance(d,list) else d.get(\"jobs\",d.get(\"queue\",[]))
for j in jobs:
    print(j.get(\"status\",\"?\"), j.get(\"title\",j.get(\"movie_clean\",\"?\")), j.get(\"progress\",\"\"))
"
'
```

### Step 3 — After downloads complete, sync to JazzMAX app DB
When files finish downloading + uploading to JazzDrive:
1. Open `http://92.4.95.252:5000/upload/api/library` to see what was uploaded
2. Add new files to the JazzMAX Watch Prototype DB so they appear in the Flutter app
3. Trigger a GitHub push so the APK build picks up any DB changes

### Step 4 — Deploy any pending code changes to Oracle
If you make code changes to radd-hub locally, always deploy with:
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
  "sudo supervisorctl restart jazzmax_radd && sleep 3 && sudo supervisorctl status jazzmax_radd"
```

## Key Files To Know

| File | What It Does |
|---|---|
| `radd-hub/hub/_legacy/scanner.py` | OTP login flow (fixed Session 6 — line ~1093) |
| `radd-hub/hub/uploader.py` | JazzDrive upload + get_active_account() |
| `radd-hub/hub/routes/upload.py` | Upload API (jd-stats, login/otp, login/verify, jazzdrive/tokens) |
| `radd-hub/hub/routes/stream.py` | Download queue API |
| `radd-hub/hub/jazzdrive.py` | JazzDrive API client |
| `radd-hub/hub/scanner.py` | Scanner orchestration |
| `_watch_prototype/` | Watch Prototype server (app backend) |
| `JAZZMAX_MASTER.md` | Full project spec + task checklist |
| `HANDOFF.md` | Step-by-step setup guide |
| `push_to_github.sh` | Push code to GitHub |

## Important Notes

- **Radd Hub login**: `admin` / `6LQRmtOM5d1PETSI`
- **JazzDrive account**: msisdn=03029688227, account id=27 (flix role)
- **The Boys S5 and Mirzapur S2** should be downloaded as season zips
- **GitHub repo**: raddclub/jazzmax-app (auto-builds APK on every push)
- **App DB**: `radd-hub/data/radd_hub.db` (Replit) — the LIVE DB is on Oracle at `/opt/jazzmax/radd-hub/data/radd_hub.db`
- If JazzDrive session expires, do OTP login at `http://92.4.95.252:5000/upload/` — the bug is fixed, it will work

## Continue Building

After handling the downloads, read `JAZZMAX_MASTER.md` Section 14 (Task Checklist) and build the next unchecked item.
