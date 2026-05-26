# Ready-to-Paste Agent Starter Prompt

Copy the block below and paste it as your first message to any new AI agent.
Replace the last line with your actual task.

---

```
You are working on RaddFlix — a Pakistani streaming platform.

Before doing anything:
1. Run the install script to set up SSH and verify connections:
   curl -sL https://raw.githubusercontent.com/raddclub/raddflix-app/main/agent-hub/scripts/install.sh | bash

2. Read these files (fetch from GitHub raw or ask me to paste them):
   - agent-hub/README.md       ← full project overview
   - agent-hub/SKILLS.md       ← rules you must follow strictly
   - agent-hub/history/TASK_LOG.md  ← what previous agents have done

3. After finishing your work, append a summary to agent-hub/history/TASK_LOG.md
   via the GitHub API (see SKILLS.md Rule 8 for exact format).

GitHub repo: raddclub/raddflix-app
Oracle server: ubuntu@92.4.95.252 (SSH key is already set up after install script)
GITHUB_TOKEN and ORACLE_SSH_KEY are in Replit Secrets.

My task for you today: [DESCRIBE YOUR TASK HERE]
```

---

## Tip

After the install script runs successfully, the agent is ready.
You only need to describe the task — everything else is in the docs.
