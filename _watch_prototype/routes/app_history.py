"""JazzMAX watch history API.

Endpoints:
  POST /api/history/<file_id>  — save watch position (auth required)
  GET  /api/history            — get user's watch history (auth required)
"""
from __future__ import annotations
import os
import logging

import jwt
from flask import Blueprint, request, jsonify
from hub import db

log = logging.getLogger("hub.app_history")

bp = Blueprint("app_history", __name__, url_prefix="/api/history")

SECRET = os.environ.get("SESSION_SECRET", "dev-secret")


def _ensure_table():
    """Create watch_history table if it doesn't exist yet."""
    conn = db.get_conn()
    conn.execute("""
        CREATE TABLE IF NOT EXISTS watch_history (
            user_id          INTEGER NOT NULL,
            file_id          TEXT    NOT NULL,
            progress_seconds INTEGER DEFAULT 0,
            completed        INTEGER DEFAULT 0,
            updated_at       TEXT    DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (user_id, file_id)
        )
    """)
    conn.commit()


def _get_user_id() -> int | None:
    """Extract user_id from Bearer JWT. Returns None on invalid/missing token."""
    auth = request.headers.get("Authorization", "")
    if not auth.startswith("Bearer "):
        return None
    token = auth[7:]
    try:
        payload = jwt.decode(token, SECRET, algorithms=["HS256"])
        return int(payload["sub"])
    except Exception:
        return None


# ── Ensure table exists on first import ──────────────────────────────────────
try:
    _ensure_table()
except Exception as e:
    log.warning("watch_history table init skipped: %s", e)


# ── Routes ───────────────────────────────────────────────────────────────────

@bp.route("/<file_id>", methods=["POST"])
def save_position(file_id: str):
    """Save watch position for a file.

    Body JSON:
      progress_seconds  int   current playback position in seconds
      completed         bool  true if the user finished the video
    """
    user_id = _get_user_id()
    if user_id is None:
        return jsonify({"error": "Unauthorized"}), 401

    data = request.get_json(silent=True) or {}
    progress = int(data.get("progress_seconds", 0))
    completed = 1 if data.get("completed", False) else 0

    try:
        conn = db.get_conn()
        conn.execute("""
            INSERT INTO watch_history (user_id, file_id, progress_seconds, completed, updated_at)
            VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(user_id, file_id) DO UPDATE SET
                progress_seconds = excluded.progress_seconds,
                completed        = excluded.completed,
                updated_at       = excluded.updated_at
        """, (user_id, file_id, progress, completed))
        conn.commit()
        return jsonify({"ok": True})
    except Exception as e:
        log.error("save_position error: %s", e)
        return jsonify({"error": "Server error"}), 500


@bp.route("", methods=["GET"])
def get_history():
    """Return user's last 50 watched items, newest first.

    Response:
      { "history": [ { file_id, progress_seconds, completed, updated_at } ] }
    """
    user_id = _get_user_id()
    if user_id is None:
        return jsonify({"error": "Unauthorized"}), 401

    try:
        conn = db.get_conn()
        rows = conn.execute("""
            SELECT file_id, progress_seconds, completed, updated_at
            FROM watch_history
            WHERE user_id = ?
            ORDER BY updated_at DESC
            LIMIT 50
        """, (user_id,)).fetchall()

        history = [
            {
                "file_id": r["file_id"],
                "progress_seconds": r["progress_seconds"],
                "completed": bool(r["completed"]),
                "updated_at": r["updated_at"],
            }
            for r in rows
        ]
        return jsonify({"history": history})
    except Exception as e:
        log.error("get_history error: %s", e)
        return jsonify({"error": "Server error"}), 500
