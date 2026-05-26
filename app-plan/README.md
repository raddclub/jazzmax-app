# JazzMAX App Plan

This folder stores every architectural plan, feature design, and technical decision for the JazzMAX app.

**Rule:** Every new idea or feature gets a plan file here BEFORE any code is written.

## Plans

| File | Status | Description |
|------|--------|-------------|
| [zero_rated_architecture.md](zero_rated_architecture.md) | APPROVED | On-device JazzDrive link generation, poster strategy, encrypted DB, zero-rated catalog sync |

## How to Add a New Plan

1. Create a `.md` file describing the feature (see any existing file for format)
2. Save it to Oracle: `/opt/jazzmax/app-plan/your_plan.md`
3. Push to GitHub from Oracle:
   ```bash
   cd /opt/jazzmax
   git add app-plan/
   git -c user.email='jazzmax@bot.local' -c user.name='JazzMAX Bot' commit -m 'docs: add plan for [feature]'
   GIT_TERMINAL_PROMPT=0 git push origin main
   ```
4. Update this README table above

## Format of Every Plan File

```markdown
# [Feature Name] — Plan
**Created:** YYYY-MM-DD
**Status:** DRAFT | APPROVED | IN PROGRESS | DONE

## Problem Being Solved
## How It Works — Each Function Explained
## Files to Create / Modify
## Implementation Order
## What Must NOT Change
```
