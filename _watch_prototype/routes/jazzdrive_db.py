"""
JazzDrive Zero-Rated Database Update Route

GET /api/jazzdrive/db_update_url
  → returns the direct JazzDrive download URL for db_update.json
  → This URL is zero-rated for Jazz SIM users (no data bundle needed)

The db_update.json file is hosted in a shared JazzDrive folder.
When new content is added to the library, this file is regenerated and uploaded.
The app downloads it every 12 hours to keep the local database current.

Format returned:
  { "url": "https://jazz.drive.url/...", "version": 1748000000, "generated_at": "..." }
"""

import json
import sqlite3
import time
from flask import Blueprint, jsonify, request

jazzdrive_db_bp = Blueprint('jazzdrive_db', __name__)

DB_UPDATE_SHARE_URL = None   # Set this after uploading db_update.json to JazzDrive
DB_UPDATE_FOLDER_PATH = None  # Local path of uploaded JSON, if needed

def _get_db():
    """Get database connection."""
    import os, sys
    sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
    try:
        from hub import db as hub_db, config
        config.load_env()
        hub_db.init_db()
        return hub_db.conn()
    except Exception:
        db_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
                               'radd-hub', 'data', 'radd_hub.db')
        return sqlite3.connect(db_path)


@jazzdrive_db_bp.route('/api/jazzdrive/db_update_url', methods=['GET'])
def get_db_update_url():
    """
    Returns the JazzDrive direct URL for the zero-rated db_update.json file.
    The Flutter app downloads this to update its local catalog without regular internet.
    """
    global DB_UPDATE_SHARE_URL
    
    if not DB_UPDATE_SHARE_URL:
        # Try to get from database settings
        try:
            with _get_db() as conn:
                row = conn.execute(
                    "SELECT v FROM settings WHERE k='jd_db_update_url'"
                ).fetchone()
                if row:
                    DB_UPDATE_SHARE_URL = row[0]
        except Exception:
            pass

    if not DB_UPDATE_SHARE_URL:
        return jsonify({
            'error': 'JazzDrive DB update URL not configured yet',
            'hint': 'Upload db_update.json to JazzDrive and set jd_db_update_url in settings'
        }), 503

    # Get current catalog version so app can check if update is needed
    try:
        with _get_db() as conn:
            version_row = conn.execute(
                "SELECT MAX(updated_at) FROM titles WHERE is_published=1"
            ).fetchone()
            version = int(version_row[0]) if version_row and version_row[0] else int(time.time())
    except Exception:
        version = int(time.time())

    return jsonify({
        'url': DB_UPDATE_SHARE_URL,
        'version': version,
        'generated_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
        'interval_hours': 12,
    })


@jazzdrive_db_bp.route('/api/jazzdrive/generate_db_update', methods=['POST'])
def generate_db_update():
    """
    Admin endpoint: generates db_update.json from current library.
    Call this after adding new content. Then upload to JazzDrive and set the URL.
    
    Returns the JSON content to upload.
    """
    # Simple auth check
    token = request.headers.get('Authorization', '').replace('Bearer ', '')
    admin_key = request.args.get('admin_key', '')
    if not admin_key and not token:
        return jsonify({'error': 'Admin auth required'}), 401

    try:
        import json as _json
        with _get_db() as conn:
            conn.row_factory = __import__("sqlite3").Row
            # Titles — join to files for movie-level file_id and share_url
            title_rows = conn.execute("""
                SELECT t.id, t.title, t.year, t.media_type, t.poster, t.rating,
                       t.genres, t.plot, t.language, t.is_free, t.updated_at,
                       f.id AS file_id, f.share_url AS file_share_url
                FROM titles t
                LEFT JOIN files f ON f.title_id = t.id
                  AND (f.season IS NULL OR f.season = 0)
                WHERE t.is_published = 1
                GROUP BY t.id
                ORDER BY t.id
            """).fetchall()

            title_ids = [r["id"] for r in title_rows]
            titles_list = []
            for r in title_rows:
                genres = []
                try:
                    genres = _json.loads(r["genres"] or "[]")
                    if not isinstance(genres, list):
                        genres = [str(genres)]
                except Exception:
                    pass
                titles_list.append({
                    "id":          r["id"],
                    "title":       r["title"] or "",
                    "year":        r["year"],
                    "media_type":  r["media_type"] or "movie",
                    "poster_url":  r["poster"] or "",
                    "rating":      float(r["rating"] or 0),
                    "genres":      genres,
                    "description": r["plot"] or "",
                    "language":    r["language"] or "",
                    "is_free":     1 if r["is_free"] else 0,
                    "db_version":  int(r["updated_at"] or 0),
                    "file_id":     r["file_id"],
                    "share_url":   r["file_share_url"] or "",
                })

            # Episodes — files table has season/episode columns
            episodes_list = []
            if title_ids:
                placeholders = ",".join("?" * len(title_ids))
                ep_rows = conn.execute(
                    f"""
                    SELECT id, title_id, filename, season, episode, share_url
                    FROM files
                    WHERE title_id IN ({placeholders})
                      AND season IS NOT NULL AND season > 0
                    ORDER BY title_id, season, episode
                    """,
                    title_ids
                ).fetchall()
                for r in ep_rows:
                    episodes_list.append({
                        "id":       r["id"],
                        "title_id": r["title_id"],
                        "file_id":  str(r["id"]),
                        "season":   r["season"],
                        "episode":  r["episode"],
                        "label":    f"S{r['season']:02d}E{r['episode']:02d}",
                        "share_url": r["share_url"] or "",
                        "quality":  None,
                        "is_free":  0,
                    })

        update_data = {
            'version': int(time.time()),
            'generated_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'titles': titles_list,
            'episodes': episodes_list,
        }

        # Save locally
        import os
        output_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
            'radd-hub', 'data', 'db_update.json'
        )
        with open(output_path, 'w', encoding='utf-8') as f:
            _json.dump(update_data, f, ensure_ascii=False, indent=2)

        return jsonify({
            'success': True,
            'titles_count': len(titles_list),
            'episodes_count': len(episodes_list),
            'version': update_data['version'],
            'saved_to': output_path,
            'next_step': 'Upload this file to JazzDrive, then call SET /api/jazzdrive/set_db_update_url'
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500


@jazzdrive_db_bp.route('/api/jazzdrive/set_db_update_url', methods=['POST'])
def set_db_update_url():
    """
    Admin endpoint: saves the JazzDrive direct URL for db_update.json.
    Call after uploading the generated JSON to JazzDrive.
    """
    global DB_UPDATE_SHARE_URL
    data = request.get_json() or {}
    url = data.get('url', '').strip()
    
    if not url:
        return jsonify({'error': 'url is required'}), 400

    DB_UPDATE_SHARE_URL = url

    # Persist to DB
    try:
        with _get_db() as conn:
            pass  # settings table already exists with k/v columns
            conn.execute(
                "INSERT OR REPLACE INTO settings (k, v) VALUES ('jd_db_update_url', ?)",
                (url,)
            )
    except Exception as e:
        return jsonify({'error': str(e)}), 500

    return jsonify({'success': True, 'url': url})
