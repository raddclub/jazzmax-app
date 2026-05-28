# RaddFlix Agent Connections Guide

> **Purpose:** This guide documents exactly how to connect to Oracle server and GitHub from a Replit agent container. It covers what works, what doesn't, and the exact patterns to use. Every future agent MUST read this before attempting any infrastructure operation.

---

## 1 — GitHub API (WORKS ✅)

### What Works
- `curl` with `$GITHUB_TOKEN` from bash works perfectly
- `$GITHUB_TOKEN` is available as a bash environment variable in the Replit container
- Raw file reads via `https://raw.githubusercontent.com/...` (no auth needed for public repo)
- GitHub Contents API (read + write single files)
- GitHub Tree/Blob API (multi-file atomic commits)

### What Does NOT Work
- `code_execution` sandbox: `process.env.GITHUB_TOKEN` is **undefined** — do NOT use JS sandbox for GitHub API calls, use bash curl only
- `git` shell commands (no git configured in container)

---

### Pattern A: Read a File (Raw, No Auth)

```bash
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/PATH/TO/FILE"
```

Use `| head -N` or `| sed -n 'X,Yp'` to read specific line ranges of large files.

---

### Pattern B: Get File SHA (Required Before Updating)

```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/contents/PATH/TO/FILE" \
  | grep '"sha"' | head -1
```

The SHA is the blob SHA of the current file — required in the PUT body to avoid conflicts.

---

### Pattern C: Update an Existing File

```bash
# 1. Write new content to temp file
cat > /tmp/new_content.md << 'EOF'
... your content here ...
EOF

# 2. Base64 encode (no line wraps)
ENCODED=$(base64 /tmp/new_content.md | tr -d '\n')

# 3. GET current SHA
SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/contents/PATH/TO/FILE" \
  | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/')

# 4. PUT with sha
curl -s -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/contents/PATH/TO/FILE" \
  -d "{
    \"message\": \"Your commit message\",
    \"content\": \"$ENCODED\",
    \"sha\": \"$SHA\"
  }"
```

---

### Pattern D: Create a New File (No SHA Required)

```bash
cat > /tmp/new_file.md << 'EOF'
... content ...
EOF

ENCODED=$(base64 /tmp/new_file.md | tr -d '\n')

curl -s -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/contents/PATH/TO/NEW_FILE" \
  -d "{
    \"message\": \"Create new file\",
    \"content\": \"$ENCODED\"
  }"
```

---

### Pattern E: Multi-File Atomic Commit (Tree API)

Use when you need to change multiple files in one commit (e.g. fixing a bug across 3 Dart files):

```bash
# Step 1: Get current HEAD SHA
HEAD_SHA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/ref/heads/main" \
  | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/')

# Step 2: Create blob for each file
BLOB1=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/blobs" \
  -d "{\"content\": \"$(base64 /tmp/file1.dart | tr -d '\n')\", \"encoding\": \"base64\"}" \
  | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/')

# Step 3: Create new tree
TREE_SHA=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/trees" \
  -d "{
    \"base_tree\": \"$HEAD_SHA\",
    \"tree\": [
      {\"path\": \"raddflix_flutter/lib/screens/file1.dart\", \"mode\": \"100644\", \"type\": \"blob\", \"sha\": \"$BLOB1\"}
    ]
  }" | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/')

# Step 4: Create commit
COMMIT_SHA=$(curl -s -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/commits" \
  -d "{
    \"message\": \"fix: your message here\",
    \"tree\": \"$TREE_SHA\",
    \"parents\": [\"$HEAD_SHA\"]
  }" | grep '"sha"' | head -1 | sed 's/.*"sha": "\([^"]*\)".*/\1/')

# Step 5: Move branch pointer (NEVER use force: true)
curl -s -X PATCH \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/raddclub/raddflix-app/git/refs/heads/main" \
  -d "{\"sha\": \"$COMMIT_SHA\", \"force\": false}"
```

---

### Pattern F: List Directory Contents

```bash
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/contents/PATH/TO/DIR" \
  | grep '"name"'
```

---

### Verification After Any Write

Always verify your commit landed:

```bash
# Check latest commit message on main
curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/raddclub/raddflix-app/commits/main" \
  | grep '"message"' | head -1

# Verify file content changed (spot-check a key line)
curl -sL "https://raw.githubusercontent.com/raddclub/raddflix-app/main/PATH/TO/FILE" \
  | grep "your new string"
```

---

## 2 — Oracle SSH (DOES NOT WORK from Replit ❌)

### Status: Port 22 Unreachable

Oracle server IP: `92.4.95.252`

**Every SSH attempt from the Replit container times out.** Port 22 is unreachable from Replit's containerized network. This has been confirmed across multiple sessions (2026-05-28).

```bash
# This WILL timeout — do not attempt:
ssh -i /tmp/oracle_key -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@92.4.95.252 "echo OK"
# Result: Connection timed out
```

### Why It Fails

Replit containers run behind NAT with outbound restrictions. Oracle's VCN (Virtual Cloud Network) security list likely only allows SSH from specific IP ranges. Replit container IPs are dynamic and not whitelisted.

### What the Key Setup Steps Are (For Reference)

Even though SSH doesn't work from Replit, here is how it's configured so you understand the setup:

```bash
# Key is stored in Replit Secrets as plain text (NOT base64 encoded)
printf '%s' "$ORACLE_SSH_KEY" > /tmp/oracle_key && chmod 600 /tmp/oracle_key
# The key includes the full PEM header/footer lines
```

### Workaround: GitHub API Only

For server-side operations that need to read/write code files that are also in the GitHub repo, use the GitHub API patterns above. All Flutter app files and agent-hub documentation files are in the GitHub repo.

**For operations that REQUIRE live server access** (e.g. restarting supervisor, checking logs, editing server-only Python files that aren't in the repo), you cannot do them from Replit. Options:
1. Document what needs to be done and note it for a human admin
2. Write the change to the repo file via GitHub API if the file is tracked in git
3. Use the `agent-hub/projects/` docs to understand the server layout and prepare the change

### Server Layout (For Context)

```
ubuntu@92.4.95.252:/opt/jazzmax/
├── radd-hub/hub/           # Main API server (port 6000) — supervisor: jazzmax_watch
├── radd-hub/admin/         # Admin panel (port 5000) — supervisor: jazzmax_radd
├── radd-hub/hub/_legacy/   # NEVER TOUCH — jazzdrive.py + scanner.py import from here
└── ...
```

Supervisor service names:
- `jazzmax_radd` — admin panel (port 5000)
- `jazzmax_watch` — watch/stream API (port 6000)

---

## 3 — Summary Decision Tree

```
Need to read a Flutter Dart file?
  → curl -sL "https://raw.githubusercontent.com/..."   ✅

Need to update a Flutter Dart file or doc?
  → GitHub Contents API (PUT) or Tree API              ✅

Need to run server commands (restart supervisor, check logs)?
  → SSH DOES NOT WORK from Replit                      ❌
  → Document for human admin or write to repo file if tracked

Need to use JS/Node for GitHub API?
  → Don't — process.env.GITHUB_TOKEN is undefined in code_execution sandbox
  → Use bash curl instead                               ✅
```

---

*Last updated: 2026-05-28 (Session 5)*

  ---

  ## 4 — Quick Tool Reference

  | Tool | Available? | Notes |
  |------|-----------|-------|
  | bash curl | ✅ Yes | Primary tool for all GitHub API calls |
  | jq | ✅ Yes (v1.7.1) | Use for parsing GitHub API JSON responses |
  | python3 | ❌ No | Not in PATH in Replit container |
  | node | ❌ No | Not directly in PATH (only via code_execution sandbox) |
  | code_execution JS sandbox | ⚠️ Limited | process.env.GITHUB_TOKEN is undefined — cannot access secrets |
  | base64 | ✅ Yes | Available; use `base64 -w 0` to avoid line wraps |
