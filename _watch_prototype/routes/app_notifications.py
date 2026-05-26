"""JazzMAX In-App Notifications API — zero-rated aware.

Endpoints:
  GET  /api/notifications              — fetch notifications (auth required, guest gets empty)
  POST /api/notifications/read         — mark notification IDs as read
  GET  /api/notifications/image/<id>   — serve broadcast image (zero-rated, same IP)
"""
from __future__ import annotations
import os
import logging
import calendar
from datetime import datetime  # FIX BUG-006
from flask import Blueprint, request, jsonify, send_file, abort, g
from hub import db
from .app_auth import require_app_auth

log = logging.getLogger("hub.app_notifications")


def _ts(val) -> int:
    """Convert SQLite CURRENT_TIMESTAMP string to Unix epoch int. FIX BUG-006."""
    if val is None:
        return 0
    if isinstance(val, int):
        return val
    try:
        dt = datetime.strptime(str(val), "%Y-%m-%d %H:%M:%S")
        return int(calendar.timegm(dt.timetuple()))
    except Exception:
        return 0
bp = Blueprint("app_notifications", __name__, url_prefix="/api/notifications")

_IMAGES_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "..", "radd-hub", "data", "notif_images"
)


def _ensure_migration():
    try:
        with db.conn() as c:
            cols = [r[1] for r in c.execute("PRAGMA table_info(broadcasts)").fetchall()]
            if "image_path" not in cols:
                c.execute("ALTER TABLE broadcasts ADD COLUMN image_path TEXT")
    except Exception:
        pass


@bp.route("/", methods=["GET"])
@require_app_auth
def get_notifications():
    _ensure_migration()
    if getattr(g, "is_guest", False) or g.app_user_id == 0:
        return jsonify({"notifications": [], "unread_count": 0})

    user_id = g.app_user_id
    with db.conn() as c:
        rows = c.execute("""
            SELECT n.id, n.broadcast_id, n.title, n.body, n.notif_type, n.is_read, n.created_at,
                   b.image_path
            FROM user_notifications n
            LEFT JOIN broadcasts b ON b.id = n.broadcast_id
            WHERE n.user_id = ?
            ORDER BY n.created_at DESC LIMIT 30
        """, (user_id,)).fetchall()

    notifs = []
    for r in rows:
        image_url = None
        if r["image_path"] and r["broadcast_id"]:
            image_url = f"/api/notifications/image/{r['broadcast_id']}"
        notifs.append({
            "id":           r["id"],
            "broadcast_id": r["broadcast_id"],
            "title":        r["title"],
            "body":         r["body"],
            "type":         r["notif_type"],
            "is_read":      bool(r["is_read"]),
            "created_at":   _ts(r["created_at"]),  # FIX BUG-006
            "image_url":    image_url,
        })

    unread = sum(1 for n in notifs if not n["is_read"])
    return jsonify({"notifications": notifs, "unread_count": unread})


@bp.route("/read", methods=["POST"])
@require_app_auth
def mark_read():
    if getattr(g, "is_guest", False) or g.app_user_id == 0:
        return jsonify({"ok": True})
    user_id = g.app_user_id
    data = request.get_json(silent=True) or {}
    ids = data.get("ids", [])
    with db.conn() as c:
        if not ids:
            c.execute("UPDATE user_notifications SET is_read=1 WHERE user_id=?", (user_id,))
        else:
            for nid in ids[:50]:
                try:
                    c.execute("UPDATE user_notifications SET is_read=1 WHERE id=? AND user_id=?",
                              (int(nid), user_id))
                except (ValueError, TypeError):
                    pass
    return jsonify({"ok": True})


@bp.route("/image/<int:broadcast_id>")
def notif_image(broadcast_id: int):
    """Serve broadcast image — on 92.4.95.252 = zero-rated for Jazz users."""
    _ensure_migration()
    with db.conn() as c:
        row = c.execute("SELECT image_path FROM broadcasts WHERE id=?",
                        (broadcast_id,)).fetchone()
    if not row or not row["image_path"]:
        abort(404)
    path = row["image_path"]
    if not os.path.isabs(path):
        path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "..", path
        )
    path = os.path.normpath(path)
    if not os.path.exists(path):
        abort(404)
    ext = os.path.splitext(path)[1].lower()
    mime = {".jpg": "image/jpeg", ".jpeg": "image/jpeg",
            ".png": "image/png", ".webp": "image/webp", ".gif": "image/gif"}.get(ext, "image/jpeg")
    return send_file(path, mimetype=mime, max_age=3600)
