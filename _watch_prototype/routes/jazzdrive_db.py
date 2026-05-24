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
                    "SELECT value FROM settings WHERE key='jd_db_update_url'"
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
        with _get_db() as conn:
            # Get all published titles
            titles = conn.execute("""
                SELECT t.id, t.title, t.year, t.media_type, t.poster, t.rating,
                       t.genres, t.plot, t.is_free,
                       f.id as file_id
                FROM titles t
                LEFT JOIN files f ON f.title_id=t.id AND f.is_primary=1
                WHERE t.is_published=1
                ORDER BY t.updated_at DESC
            """).fetchall()

            # Get all episodes for TV shows
            episodes = conn.execute("""
                SELECT e.id, e.title_id, e.season, e.episode, e.label, 
                       e.quality, e.is_free, f.id as file_id
                FROM episodes e
                JOIN files f ON f.id=e.file_id
                JOIN titles t ON t.id=e.title_id
                WHERE t.is_published=1
            """).fetchall()

        import json
        titles_list = []
        for t in titles:
            titles_list.append({
                'id': t[0],
                'title': t[1] or '',
                'year': t[2] or 0,
                'media_type': t[3] or 'movie',
                'poster_url': t[4] or '',
                'rating': float(t[5] or 0),
                'genres': t[6] or '[]',
                'description': t[7] or '',
                'is_free': t[8] or 0,
                'file_id': str(t[9]) if t[9] else None,
            })

        episodes_list = []
        for ep in episodes:
            episodes_list.append({
                'id': ep[0],
                'title_id': ep[1],
                'season': ep[2] or 1,
                'episode': ep[3] or 1,
                'label': ep[4] or '',
                'quality': ep[5] or '',
                'is_free': ep[6] or 0,
                'file_id': str(ep[7]) if ep[7] else None,
            })

        update_data = {
            'version': int(time.time()),
            'generated_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
            'titles': titles_list,
            'episodes': episodes_list,
            'removed_ids': [],
        }

        # Save locally
        import os
        output_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
            'radd-hub', 'data', 'db_update.json'
        )
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(update_data, f, ensure_ascii=False, indent=2)

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
            conn.execute("CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT)")
            conn.execute(
                "INSERT OR REPLACE INTO settings (key, value) VALUES ('jd_db_update_url', ?)",
                (url,)
            )
    except Exception as e:
        return jsonify({'error': str(e)}), 500

    return jsonify({'success': True, 'url': url})
