# RaddFlix Agent Memory Index

- [Full Audit Bugs](raddflix-audit-bugs.md) — 34 bugs found 2026-05-30, BUG-A01..A34; all code-level bugs fixed (see table)
- [DB Migration Rules](raddflix-db-rules.md) — `oldV` not `oldVersion`, sqflite pin, ON CONFLICT compat, current DB v13
- [Phase 13 Fix Status](raddflix-audit-bugs.md) — Batches 1-7 complete. A29/A31/A33 remain (architectural/infra/design scope)
- [GitHub Commit Pattern](raddflix-db-rules.md) — blob→tree→commit→PATCH ref; large files use Python urllib not curl -d for base64
- [CODE_MAP location](raddflix-db-rules.md) — agent-hub/CODE_MAP.md maps every file to purpose/functions/known bugs
- [Memory restore commands](raddflix-db-rules.md) — fetch agent-hub/memory/*.md and write to .agents/memory/ at session start

- [CI Status](raddflix-db-rules.md) — CI GREEN as of commit 200ff61; all compile errors fixed, APK builds successfully
- [Flask strict_slashes rule](raddflix-db-rules.md) — ALL empty-string blueprint routes need strict_slashes=False or nginx redirects them; applies to bp_rec, bp_hist, bp_usage, bp_pay
- [nginx exact-match locations](raddflix-db-rules.md) — add `location = /api/X` before `location /api/X/` for any endpoint Flask calls without trailing slash to avoid 301 round-trips
