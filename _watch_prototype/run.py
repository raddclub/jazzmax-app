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

# Read PORT before load_env() — radd-hub .env may override it otherwise
_port = int(os.environ.get("PORT", 6000))

config.ensure_dirs()
config.load_env()
db.init_db()

app = Flask(
    __name__,
    template_folder=str(Path(__file__).parent / "templates"),
)
CORS(app)
app.config["SECRET_KEY"] = "watch-prototype-dev"

app.register_blueprint(watch_bp)
app.register_blueprint(app_auth_bp)
app.register_blueprint(app_catalog_bp)
app.register_blueprint(app_subscription_bp)

@app.route("/")
def root():
    return redirect("/watch")


if __name__ == "__main__":
    print(f"\n  Watch Prototype  →  http://localhost:{_port}/watch\n")
    app.run(host="0.0.0.0", port=_port, debug=False)
