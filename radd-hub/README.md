# Radd Hub v3.0 — RaddFlix Admin Panel

Flask-based admin panel for the RaddFlix streaming platform.

**Runs on:** Oracle server `92.4.95.252`, port `5000`
**Supervisor service:** `jazzmax_radd`
**Server path:** `/opt/jazzmax/radd-hub/`

## Quick Reference

```bash
# Restart
sudo supervisorctl restart jazzmax_radd

# Logs
sudo supervisorctl tail -f jazzmax_radd

# Status
sudo supervisorctl status
```

## Key Routes
- `/` — Admin dashboard
- `/api/trending` — Trending content (used by mobile app)
- `/api/library` — Full content library
- `/api/stream` — Stream URL generator
- `/health` — Health check

## CRITICAL
Never delete or modify `hub/_legacy/`. It is required by `jazzdrive.py` and `scanner.py`.

→ Full documentation: [`agent-hub/projects/radd-hub.md`](../agent-hub/projects/radd-hub.md)
