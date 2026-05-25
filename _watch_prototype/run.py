"""Standalone runner for the Watch prototype.

Connects to the Radd Hub database so you can preview the watch UI
without it being part of the main Radd Hub application.
"""
import sys
import os
from pathlib import Path

# Add radd-hub to path so we can reuse its db + jazzdrive modules
ROOT = Path(__file__).parent.parent
RADD_HUB = ROOT / "radd-hub"
sys.path.insert(0, str(RADD_HUB))

# Add _watch_prototype to path so local routes package is importable
sys.path.insert(0, str(Path(__file__).parent))

# Point config to the real radd-hub data directory
os.environ.setdefault("RADD_HUB_DATA_DIR", str(RADD_HUB / "data"))

from flask import Flask, redirect
from flask_cors import CORS

from hub import config, db
from routes.watch import bp as watch_bp
from routes.app_auth import bp as app_auth_bp
from routes.app_catalog import bp as app_catalog_bp
from routes.app_subscription import bp as app_subscription_bp
from routes.app_history import bp as app_history_bp
from routes.app_search import bp as app_search_bp
from routes.jazzdrive_db import jazzdrive_db_bp
from routes.poster_proxy import poster_proxy_bp
from routes.sms_gateway import sms_bp as sms_gateway_bp
from routes.app_version import bp as app_version_bp, version_gate_middleware
from routes.app_plans import bp as app_plans_bp
import routes.app_notifications as _notif_mod; app_notifications_bp = _notif_mod.bp

# Read PORT before load_env() — radd-hub .env may override it otherwise
_port = int(os.environ.get("PORT", 6000))

config.ensure_dirs()
config.load_env()
db.init_db()

app = Flask(
    __name__,
    template_folder=str(Path(__file__).parent / "templates"),
)
# Restrict CORS to known app origins (Flutter app + admin)
_allowed_origins = [
    "http://92.4.95.252",
    "https://92.4.95.252",
    # Add your custom domain here when you get one, e.g.:
    # "https://jazzmax.pk",
]
# In development/emulator, allow all — controlled by env var
_cors_origins = "*" if os.environ.get("CORS_ALLOW_ALL") else _allowed_origins
CORS(app,
     origins=_cors_origins,
     supports_credentials=True,
     allow_headers=["Authorization", "Content-Type", "X-Device-ID"],
     methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
     max_age=600)
app.config["SECRET_KEY"] = (
    os.environ.get("SESSION_SECRET") or
    os.environ.get("FLASK_SECRET_KEY") or
    os.environ.get("SECRET_KEY")
)
if not app.config["SECRET_KEY"] or len(app.config["SECRET_KEY"]) < 16:
    import secrets as _sec
    _gen = _sec.token_hex(32)
    app.config["SECRET_KEY"] = _gen
    # Persist generated key so restarts don't invalidate sessions
    try:
        from hub import db as _hdb
        with _hdb.conn() as _c:
            _c.execute("INSERT OR IGNORE INTO settings(k,v) VALUES('flask_secret_key',?)", (_gen,))
            _row = _c.execute("SELECT v FROM settings WHERE k='flask_secret_key'").fetchone()
            app.config["SECRET_KEY"] = _row["v"] if _row else _gen
    except Exception:
        pass

app.register_blueprint(app_version_bp)
app.register_blueprint(watch_bp)
app.register_blueprint(app_auth_bp)
app.register_blueprint(app_catalog_bp)
app.register_blueprint(app_subscription_bp)
app.register_blueprint(app_history_bp)
app.register_blueprint(app_search_bp)
app.register_blueprint(jazzdrive_db_bp)
app.register_blueprint(poster_proxy_bp)
app.register_blueprint(sms_gateway_bp)
app.register_blueprint(app_plans_bp)
app.register_blueprint(app_notifications_bp)


@app.route("/api/queue/status")
def _proxy_queue_status():
    """Proxy the download queue status from radd-hub for the Flutter admin screen."""
    import urllib.request as _urllib
    try:
        with _urllib.urlopen("http://127.0.0.1:5000/api/queue/status", timeout=5) as r:
            from flask import Response
            return Response(r.read(), status=r.status, mimetype="application/json")
    except Exception as e:
        from flask import jsonify as _fj2
        return _fj2({"ok": False, "jobs": [], "error": str(e)}), 200

@app.route("/")
def root():
    return redirect("/watch")

# ── APK version + tamper gate (before every request) ─────────────────────────
@app.before_request
def _version_gate():
    return version_gate_middleware()


@app.after_request
def _security_headers(resp):
    # Flask adds Server header (nginx sets the rest globally)
    resp.headers["Server"]  = "JazzMAX"
    # Remove X-Powered-By if Flask adds it
    resp.headers.pop("X-Powered-By", None)
    return resp


# ── Generic error handlers: no stack traces exposed ──────────────────────────
from flask import jsonify as _fj

@app.errorhandler(400)
def _e400(e): return _fj({"error": "bad request"}), 400

@app.errorhandler(405)
def _e405(e): return _fj({"error": "method not allowed"}), 405

@app.errorhandler(401)
def _e401(e): return _fj({"error": "unauthorized"}), 401

@app.errorhandler(403)
def _e403(e): return _fj({"error": "forbidden"}), 403

@app.errorhandler(404)
def _e404(e): return _fj({"error": "not found"}), 404

@app.errorhandler(429)
def _e429(e): return _fj({"error": "too many requests", "retry_after": 60}), 429

@app.errorhandler(500)
def _e500(e):
    import logging
    logging.getLogger("hub.app").error("Unhandled 500: %s", e)
    return _fj({"error": "internal server error"}), 500

@app.errorhandler(Exception)
def _eAny(e):
    import logging
    logging.getLogger("hub.app").error("Unhandled exception: %s", type(e).__name__)
    return _fj({"error": "internal error"}), 500


if __name__ == '__main__':
    print(f'  Watch Prototype  →  http://localhost:{_port}/watch')
    app.run(host='0.0.0.0', port=_port, debug=False)
