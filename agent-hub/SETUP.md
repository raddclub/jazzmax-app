# Environment Setup Guide

## Required Replit Secrets

| Secret | What it is |
|---|---|
| `GITHUB_TOKEN` | GitHub personal access token for `raddclub` account (repo scope) |
| `ORACLE_SSH_KEY` | SSH private key for Oracle server — base64-encoded (see below) |

---

## How to encode the SSH key

On your local machine:
```bash
base64 -w 0 ~/.ssh/your_oracle_key > key_encoded.txt
cat key_encoded.txt
```
Paste the entire output (one long line) as the `ORACLE_SSH_KEY` Replit secret.

---

## SSH Key Decode — CRITICAL, use this exact pattern every session

The key may have embedded spaces when retrieved from Replit secrets. Always use this decode:

```python
python3 -c "
import os, base64, subprocess
raw = os.environ['ORACLE_SSH_KEY'].strip()
header = '-----BEGIN OPENSSH PRIVATE KEY-----'
footer = '-----END OPENSSH PRIVATE KEY-----'
body = raw.replace(header,'').replace(footer,'').strip().replace(' ','')
lines = '\\n'.join(body[i:i+64] for i in range(0,len(body),64))
key = header + '\\n' + lines + '\\n' + footer + '\\n'
open('/tmp/oracle_key','w').write(key)
subprocess.run(['chmod','600','/tmp/oracle_key'])
print('SSH key written OK')
"
```

---

## Verify Connections

```bash
# Oracle
ssh -i /tmp/oracle_key -o StrictHostKeyChecking=no ubuntu@92.4.95.252 \
  "echo Oracle OK && sudo supervisorctl status"

# GitHub
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  https://api.github.com/repos/raddclub/raddflix-app \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('GitHub OK:', d['full_name'], '| public:', not d.get('private',True))"
```

---

## Server Reference

```
OS:         Ubuntu 24.04 LTS (Oracle Cloud Always Free)
Arch:       aarch64 (ARM64)  ← important for architecture-specific installs
IP:         92.4.95.252
User:       ubuntu
Root dir:   /opt/jazzmax/
Python:     3.12
Java:       OpenJDK 21 (pre-installed)
Supervisor: jazzmax_radd (port 5000), jazzmax_watch (port 6000)
SQLite DB:  /opt/jazzmax/radd-hub/data/raddflix.db
```

---

## GitHub Notes

- **Repo is PUBLIC** (changed in Session 5) — unlimited free GitHub Actions minutes on `ubuntu-latest`
- Active workflows: `build-apk.yml` and `ci-tests.yml`
- Legacy workflow `build_apk.yml` (underscore) — **DELETE IT** (wrong paths, old Flutter)
- All GitHub file writes must use the Contents API (PUT with base64 content + current file SHA)
- Never use git shell commands from Replit main agent
