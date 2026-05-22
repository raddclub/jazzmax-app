from __future__ import annotations
import json, sys, time, re, os
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import radd_flix as rf
KNOWN_PUBLIC_SHARE = "https://cloud.jazzdrive.com.pk/share/OR6EEKTACKBJG9R9"
CLOUD = "https://cloud.jazzdrive.com.pk"
PROBE_PATHS = [
    ("GET",  "/sapi/share?action=get",                      {"id": "{fid}"}),
    ("GET",  "/sapi/share?action=create",                   {"id": "{fid}"}),
    ("POST", "/sapi/share?action=create",                   {"id": "{fid}"}),
    ("POST", "/sapi/share?action=save",                     {"id": "{fid}"}),
    ("GET",  "/sapi/share?action=list",                     {}),
    ("POST", "/sapi/share/save",                            {"id": "{fid}"}),
    ("GET",  "/sapi/file/share?action=get",                 {"id": "{fid}"}),
    ("POST", "/sapi/file/share?action=save",                {"id": "{fid}"}),
    ("GET",  "/sapi/media/share?action=get",                {"id": "{fid}"}),
    ("POST", "/sapi/media/share?action=create",             {"id": "{fid}"}),
    ("GET",  "/sapi/sharing?action=get",                    {"id": "{fid}"}),
    ("POST", "/sapi/sharing?action=create",                 {"id": "{fid}"}),
    ("GET",  "/sapi/media/video?action=share",              {"id": "{fid}"}),
    ("POST", "/sapi/media/video?action=share",              {"id": "{fid}"}),
    ("POST", "/sapi/share?action=create",                   {"fileid":  "{fid}"}),
    ("POST", "/sapi/share?action=create",                   {"file_id": "{fid}"}),
    ("POST", "/sapi/share?action=create",                   {"itemId":  "{fid}"}),
]
def section(title):
    print("\n" + "=" * 78)
    print(title)
    print("=" * 78)
def safe_dump(obj, max_chars=4000):
    try:
        s = json.dumps(obj, indent=2, default=str, ensure_ascii=False)
    except Exception:
        s = repr(obj)
    if len(s) > max_chars:
        s = s[:max_chars] + f"\n…(truncated {len(s) - max_chars} chars)"
    return s
def run():
    cfg = rf.load_config()
    section("STEP 1 — Login (OTP required)")
    session, tokens = rf.login(cfg)
    cfg["session"] = tokens
    rf.save_config(cfg)
    print(" ✓ Session established.")
    print("   validation_key (masked):", (tokens.get("validation_key") or "")[:6] + "…")
    headers = rf._auth_headers(tokens) if hasattr(rf, "_auth_headers") else {}
    section("STEP 2 — /sapi/media/video?action=get  (full raw JSON)")
    r = session.get(
        f"{CLOUD}/sapi/media/video?action=get",
        headers=headers, timeout=20,
    )
    print(f"  HTTP {r.status_code}")
    try:
        data = r.json()
    except Exception:
        data = {"raw": r.text[:1000]}
    items = []
    if isinstance(data, dict):
        for key in ("data", "items", "list", "videos", "result"):
            if isinstance(data.get(key), list):
                items = data[key]; break
    elif isinstance(data, list):
        items = data
    print(f"  -> total files returned: {len(items)}")
    if items:
        print("\n  --- FIRST FILE (full record) ---")
        print(safe_dump(items[0]))
        print("\n  --- ALL TOP-LEVEL KEYS ACROSS FILES ---")
        keys = set()
        for it in items:
            if isinstance(it, dict):
                keys.update(it.keys())
        print("  ", sorted(keys))
        share_fields = [k for k in keys if "share" in k.lower()]
        print("  share-like fields:", share_fields or "(none)")
        first_id = items[0].get("id") or items[0].get("file_id")
    else:
        first_id = None
        print("  no items found — cannot probe with a real file id")
    section(f"STEP 3 — public share page (NO auth): {KNOWN_PUBLIC_SHARE}")
    import requests
    try:
        public = requests.get(KNOWN_PUBLIC_SHARE, timeout=20, allow_redirects=True)
        print(f"  HTTP {public.status_code}")
        print(f"  final URL: {public.url}")
        body = public.text
        print(f"  body length: {len(body)} chars")
        for pat in [
            r'https?://[^"\']+\.mp4[^"\']*',
            r'https?://[^"\']+\.m3u8[^"\']*',
            r'https?://[^"\']+\.mpd[^"\']*',
            r'"(?:src|file|url|videoSrc|sources?)"\s*:\s*"([^"]+)"',
            r'/sapi/[a-zA-Z0-9_/?=&.-]+',
            r'token["\']?\s*[:=]\s*["\']([^"\']{8,})',
            r'expir\w*["\']?\s*[:=]\s*["\']?([0-9TZ:.-]+)',
        ]:
            hits = re.findall(pat, body)[:5]
            if hits:
                print(f"  pattern {pat!r}:")
                for h in hits[:5]:
                    print("     ", h if isinstance(h, str) else h)
        print("\n  --- HTML head (first 50 lines) ---")
        for line in body.splitlines()[:50]:
            print("    " + line[:160])
    except Exception as e:
        print("  fetch failed:", e)
    section("STEP 4 — probe share endpoints against file id")
    if not first_id:
        print("  no file id — skipping")
        return
    print(f"  using file id: {first_id}")
    for method, path, params in PROBE_PATHS:
        url = f"{CLOUD}{path}"
        params = {k: str(v).format(fid=first_id) for k, v in params.items()}
        try:
            if method == "GET":
                rr = session.get(url, params=params, headers=headers, timeout=15)
            else:
                rr = session.post(url, data=params, headers=headers, timeout=15)
            ct = rr.headers.get("content-type", "")
            preview = ""
            try:
                j = rr.json()
                preview = " " + safe_dump(j, max_chars=300).replace("\n", " ")
            except Exception:
                preview = " " + rr.text[:200].replace("\n", " ")
            tag = "★" if rr.status_code == 200 and ("share" in (rr.text or "").lower() or "OR6" in (rr.text or "") or "url" in (rr.text or "").lower()) else " "
            print(f"  {tag} {method:4s} {path:48s} {params}  -> {rr.status_code} ({ct}){preview[:200]}")
        except Exception as e:
            print(f"    {method:4s} {path}  -> ERROR {e}")
if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        print("\nAborted.")