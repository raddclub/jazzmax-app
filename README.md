# RaddFlix — Pakistan ka Entertainment, Data-Free

**RaddFlix** is a Pakistani streaming platform built for Jazz SIM users. Content is streamed via JazzDrive CDN (zero-rated — no data charges). Users can watch movies/dramas without consuming their mobile data.

## What's in this repo

| Folder | What it is |
|--------|-----------|
| `radd-hub/` | Flask admin panel (Radd Hub v3.0) — content management, user management, subscriptions, analytics |
| `jazzmax_flutter/` | Flutter mobile app — the user-facing streaming app |
| `_watch_prototype/` | Early prototype of watch API (reference only) |
| `scripts/` | Utility scripts (firewall, oracle setup, push helpers) |
| `agent-hub/` | **AI agent coordination system** — read this if you are an AI agent |

## Live Infrastructure

| Component | Location | Port |
|-----------|----------|------|
| Oracle Ubuntu Server | `ubuntu@92.4.95.252` | — |
| Radd Hub (admin panel) | Oracle server | 5000 |
| Watch API (mobile backend) | Oracle server | 6000 |
| GitHub repo | `raddclub/raddflix-app` | — |

## Quick links for AI agents

→ Start here: [`agent-hub/README.md`](agent-hub/README.md)
→ Task history: [`agent-hub/history/TASK_LOG.md`](agent-hub/history/TASK_LOG.md)
→ Rules: [`agent-hub/SKILLS.md`](agent-hub/SKILLS.md)
→ Setup script: [`agent-hub/scripts/install.sh`](agent-hub/scripts/install.sh)
