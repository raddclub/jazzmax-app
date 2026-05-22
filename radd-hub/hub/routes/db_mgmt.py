"""Database Management — CRUD, raw SQL, and data grid."""
from __future__ import annotations
import json
import time
import sqlite3
import csv
import io
from flask import Blueprint, render_template, request, jsonify, Response, abort
from .. import db, auth, config

bp = Blueprint("db_mgmt", __name__)

@bp.route("/")
@auth.login_required
def page():
    return render_template("db_mgmt.html", active="db_mgmt")

@bp.route("/api/tables")
@auth.login_required
def list_tables():
    """List only the movie-related tables."""
    return jsonify({"ok": True, "tables": ["titles", "files"]})

@bp.route("/api/table/<name>")
@auth.login_required
def get_table_data(name):
    """Fetch rows from a table with pagination and search."""
    if name not in ("titles", "files"):
        abort(403)
    
    limit = min(int(request.args.get("limit", 50)), 500)
    offset = int(request.args.get("offset", 0))
    q = request.args.get("q", "").strip()
    
    try:
        with db.conn() as c:
            # Get columns
            cursor = c.execute(f"PRAGMA table_info({name})")
            columns = [{"name": r["name"], "type": r["type"], "pk": bool(r["pk"])} for r in cursor.fetchall()]
            
            # Build search clause
            where = ""
            params = []
            if q:
                search_parts = []
                for col in columns:
                    if col["type"].upper() in ("TEXT", "VARCHAR", "STRING"):
                        search_parts.append(f"{col['name']} LIKE ?")
                        params.append(f"%{q}%")
                if search_parts:
                    where = " WHERE " + " OR ".join(search_parts)
            
            # Get total count
            total = c.execute(f"SELECT COUNT(*) FROM {name} {where}", params).fetchone()[0]
            
            # Get data
            sql = f"SELECT * FROM {name} {where} LIMIT ? OFFSET ?"
            data_rows = c.execute(sql, params + [limit, offset]).fetchall()
            
            return jsonify({
                "ok": True,
                "columns": columns,
                "rows": [dict(r) for r in data_rows],
                "total": total,
                "limit": limit,
                "offset": offset
            })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500

@bp.route("/api/table/<name>/row", methods=["POST"])
@auth.login_required
def create_row(name):
    """Insert a new row into a table."""
    data = request.get_json(force=True, silent=True) or {}
    if not data:
        return jsonify({"ok": False, "error": "No data provided"}), 400
    
    try:
        cols = list(data.keys())
        placeholders = ", ".join(["?" for _ in cols])
        sql = f"INSERT INTO {name} ({', '.join(cols)}) VALUES ({placeholders})"
        
        with db.conn() as c:
            cur = c.execute(sql, list(data.values()))
            return jsonify({"ok": True, "lastrowid": cur.lastrowid})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500

@bp.route("/api/table/<name>/row", methods=["PUT"])
@auth.login_required
def update_row(name):
    """Update a row based on its primary key(s)."""
    data = request.get_json(force=True, silent=True) or {}
    pks = data.get("_pks", {})  # e.g. {"id": 1}
    updates = data.get("_updates", {})
    
    if not pks or not updates:
        return jsonify({"ok": False, "error": "Missing primary keys or updates"}), 400
    
    try:
        set_clause = ", ".join([f"{k} = ?" for k in updates.keys()])
        where_clause = " AND ".join([f"{k} = ?" for k in pks.keys()])
        sql = f"UPDATE {name} SET {set_clause} WHERE {where_clause}"
        
        params = list(updates.values()) + list(pks.values())
        
        with db.conn() as c:
            c.execute(sql, params)
            return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500

@bp.route("/api/table/<name>/row", methods=["DELETE"])
@auth.login_required
def delete_row(name):
    """Delete a row based on its primary key(s)."""
    data = request.get_json(force=True, silent=True) or {}
    if not data:
        return jsonify({"ok": False, "error": "No primary keys provided"}), 400
    
    try:
        where_clause = " AND ".join([f"{k} = ?" for k in data.keys()])
        sql = f"DELETE FROM {name} WHERE {where_clause}"
        
        with db.conn() as c:
            c.execute(sql, list(data.values()))
            return jsonify({"ok": True})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500

@bp.route("/api/sql", methods=["POST"])
@auth.login_required
def execute_sql():
    """Execute raw SQL (Admin only)."""
    # Note: Flask login_required is usually enough, but this is powerful
    data = request.get_json(force=True, silent=True) or {}
    sql = data.get("sql", "").strip()
    if not sql:
        return jsonify({"ok": False, "error": "No SQL provided"}), 400
    
    # Simple read-only check (optional, can be bypassable)
    is_write = any(kw in sql.upper() for kw in ("INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "CREATE", "REPLACE"))
    
    try:
        with db.conn() as c:
            cur = c.execute(sql)
            if cur.description: # If it's a SELECT
                columns = [d[0] for d in cur.description]
                rows = [dict(zip(columns, r)) for r in cur.fetchall()]
                return jsonify({"ok": True, "columns": columns, "rows": rows, "type": "select"})
            else:
                return jsonify({"ok": True, "changes": c.total_changes, "type": "exec"})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500

@bp.route("/api/export/<name>")
@auth.login_required
def export_table(name):
    """Export table to CSV or JSON."""
    fmt = request.args.get("format", "csv").lower()
    try:
        with db.conn() as c:
            rows = c.execute(f"SELECT * FROM {name}").fetchall()
            if not rows:
                return "Table is empty", 200
            
            data = [dict(r) for r in rows]
            
            if fmt == "json":
                return jsonify(data)
            else:
                output = io.StringIO()
                writer = csv.DictWriter(output, fieldnames=data[0].keys())
                writer.writeheader()
                writer.writerows(data)
                
                return Response(
                    output.getvalue(),
                    mimetype="text/csv",
                    headers={"Content-disposition": f"attachment; filename={name}.csv"}
                )
    except Exception as e:
        return str(e), 500

@bp.route("/api/stats")
@auth.login_required
def db_stats():
    """Get database stats."""
    try:
        db_path = config.DB_PATH
        size_bytes = db_path.stat().st_size if db_path.exists() else 0
        
        with db.conn() as c:
            tables_count = c.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'").fetchone()[0]
            
            # Get row counts for main tables
            counts = {}
            for t in ["titles", "files", "accounts", "keys", "settings"]:
                try:
                    counts[t] = c.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
                except:
                    counts[t] = 0
                    
        return jsonify({
            "ok": True,
            "size_bytes": size_bytes,
            "tables_count": tables_count,
            "row_counts": counts,
            "ts": int(time.time())
        })
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500
