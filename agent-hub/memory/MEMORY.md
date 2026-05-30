# RaddFlix Agent Memory Index

- [Full Audit Bugs](raddflix-audit-bugs.md) — 34 bugs found 2026-05-30, BUG-A01..A34; all code-level bugs fixed (see table)
- [DB Migration Rules](raddflix-db-rules.md) — `oldV` not `oldVersion`, sqflite pin, ON CONFLICT compat, current DB v13
- [Phase 13 Fix Status](raddflix-audit-bugs.md) — Batches 1-7 complete. A29/A31/A33 remain (architectural/infra/design scope)
- [GitHub Commit Pattern](raddflix-db-rules.md) — blob→tree→commit→PATCH ref; large files use Python urllib not curl -d for base64
- [CODE_MAP location](raddflix-db-rules.md) — agent-hub/CODE_MAP.md maps every file to purpose/functions/known bugs
- [Memory restore commands](raddflix-db-rules.md) — fetch agent-hub/memory/*.md and write to .agents/memory/ at session start
