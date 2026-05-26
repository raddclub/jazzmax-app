# Radd Hub v3.0 — Flask Admin Panel

## What it is
The admin panel for RaddFlix. Admins manage content (movies/dramas), users, subscriptions, payments, and analytics from a web dashboard.

## Location
- **Server:** `/opt/jazzmax/radd-hub/`
- **GitHub:** `radd-hub/` folder in `raddclub/raddflix-app`
- **Runs on:** port 5000 (supervisor service: `jazzmax_radd`)

## Tech Stack
- Python 3.12
- Flask (blueprints pattern)
- SQLite database
- Jinja2 templates
- Gunicorn (production WSGI)

## Key Files

| File | Purpose |
|------|---------|
| `hub/app.py` | Flask app factory, registers all blueprints, /health route |
| `hub/routes/library.py` | Content library API (movies, dramas, trending) |
| `hub/routes/admin.py` | Admin user management |
| `hub/routes/stream.py` | Stream URL generation (calls JazzDrive) |
| `hub/routes/subscriptions.py` | Subscription management |
| `hub/routes/analytics.py` | View stats, watch counts |
| `hub/routes/payment_gateway.py` | Payment processing |
| `hub/jazzdrive.py` | JazzDrive CDN integration (generates stream URLs) |
| `hub/scanner.py` | Content scanner (scans JazzDrive for new content) |
| `hub/_legacy/` | **DO NOT TOUCH** — jazzdrive.py and scanner.py import from here |
| `hub/templates/` | Jinja2 HTML templates for admin UI |

## How to Restart

```bash
sudo supervisorctl restart jazzmax_radd
sudo supervisorctl status
```

## How to Check Logs

```bash
sudo supervisorctl tail -f jazzmax_radd
# or
tail -f /var/log/supervisor/jazzmax_radd-stdout.log
```

## Routes / Endpoints (summary)

| Route | Method | Purpose |
|-------|--------|---------|
| `/` | GET | Admin dashboard home |
| `/api/trending` | GET | Trending titles (used by mobile app) |
| `/api/library` | GET | Full content library |
| `/api/stream` | GET | Generate stream URL for a title |
| `/health` | GET | Health check (returns OK) |
| `/admin/users` | GET | User management |
| `/admin/subscriptions` | GET | Subscription management |

## Database
- SQLite file on server: `/opt/jazzmax/radd-hub/radd.db`
- Schema managed via Flask-SQLAlchemy or raw SQL (check `hub/db.py`)

## CRITICAL: _legacy folder
`hub/_legacy/` contains early JazzDrive auth code. `jazzdrive.py` and `scanner.py` do:
```python
from hub._legacy.jazzdrive_login import ...
from hub._legacy.otp_handler import ...
```
If this folder is missing, streaming completely breaks. It is intentionally not in GitHub (added to .gitignore). It exists only on the server.
