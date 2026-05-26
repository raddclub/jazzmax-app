# Environment Setup Guide

## Required Replit Secrets

Set these two secrets in Replit before running any agent:

| Secret name | What it is | Where to get it |
|-------------|-----------|-----------------|
| `GITHUB_TOKEN` | GitHub personal access token for `raddclub` account | GitHub → Settings → Developer Settings → Personal access tokens → Fine-grained or Classic (needs repo scope) |
| `ORACLE_SSH_KEY` | SSH private key for Oracle server, base64-encoded | See below |

---

## How to encode the SSH key

On your local machine (the one that has the key):

```bash
base64 -w 0 ~/.ssh/your_oracle_key > key_encoded.txt
cat key_encoded.txt
```

Copy the entire output (one long line) and paste it as the `ORACLE_SSH_KEY` secret value in Replit.

> Note: The key may get spaces inserted when stored. The install script handles this automatically by stripping spaces before decoding.

---

## One-Line Install Script

Once secrets are set, paste this in the Replit shell:

```bash
curl -sL https://raw.githubusercontent.com/raddclub/raddflix-app/main/agent-hub/scripts/install.sh | bash
```

This script will:
1. Strip spaces from `ORACLE_SSH_KEY` and decode it to `/tmp/oracle_key`
2. Set permissions (`chmod 600`)
3. Test SSH connection to Oracle server
4. Verify `GITHUB_TOKEN` works against the GitHub API
5. Pull latest `agent-hub/` contents and print a summary
6. Print ready message with next steps

---

## Manual Setup (if curl fails)

```bash
# Step 1: set up SSH key
echo "$ORACLE_SSH_KEY" | tr -d ' ' | base64 -d > /tmp/oracle_key
chmod 600 /tmp/oracle_key

# Step 2: test Oracle connection
ssh -i /tmp/oracle_key -o StrictHostKeyChecking=no ubuntu@92.4.95.252 "echo 'Oracle OK'"

# Step 3: test GitHub token
curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/raddclub/raddflix-app | python3 -c "import sys,json; d=json.load(sys.stdin); print('GitHub OK:', d.get('full_name','ERROR'))"
```

---

## Server Details (for reference)

```
OS:        Ubuntu (Oracle Cloud, Always Free tier)
IP:        92.4.95.252
User:      ubuntu
Root dir:  /opt/jazzmax/
Python:    3.12.3
Node.js:   20.x
Supervisor: manages jazzmax_radd (port 5000) and jazzmax_watch (port 6000)
```
