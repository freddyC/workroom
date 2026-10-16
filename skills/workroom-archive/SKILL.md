---
name: workroom-archive
description: >
  Permanently archive and clean up a completed workroom, preserving its work log
  in the archive. Use when: (1) the user invokes /workroom-archive; (2) says
  "archive this workroom", "I'm done with this workroom", "clean up the workroom",
  "the PR is merged, archive it", "delete the workroom", or any phrasing indicating
  the work is complete and the local directory should be removed. Do NOT use when
  the user just wants to pause — use workroom-close for that.
---

# Workroom: Archive

Two-phase process: checklist first, delete only after explicit user confirmation.

## Step 1: Run the Archive Script (Checklist Phase)

```bash
bash "$(dirname "$0")/../../scripts/workroom-archive.sh" \
  [--base-dir DIR] \
  [--workroom NAME]
```

If the user's cwd is inside a workroom, `--workroom` can be omitted.

## Step 2: Present the Checklist

Read the JSON (`"phase": "checklist"`). If `"all_clean": false`, surface any
warnings before proceeding:

> "Before archiving, a couple of things to sort out in [repo]:
>   ⚠ 2 uncommitted changes
>   ⚠ 1 unpushed commit
>
> Want me to commit and push before archiving?"

Handle any outstanding items (commit, push) before continuing.

If no PR URL was mentioned yet, ask:
> "Has a PR been opened for this work? Paste the link and I'll record it, or
> say 'no PR' to skip."

## Step 3: Confirm Deletion

Always ask explicitly — include the full path:

> "Work log will be saved to workroom-archive/. All commits, branches, and PRs
> are safe on the remote. Safe to delete the local directory at `<workroom_dir>`?"

Wait for an explicit "yes" before proceeding.

## Step 4: Run the Archive Script (Delete Phase)

```bash
bash "$(dirname "$0")/../../scripts/workroom-archive.sh" \
  [--base-dir DIR] \
  --workroom NAME \
  --outcome "Brief one-line summary of what was accomplished" \
  [--pr-url URL] \
  --confirm-delete
```

## Step 5: Confirm

```
Workroom archived: workroom-ABC-123-fix-auth

Work log → workroom-archive/WORKLOG-2025-06-04-fix-auth.md
ACCOMPLISHMENTS.md updated
Local directory deleted

All commits and PRs are preserved on the remote.
```

## Notes

- `ACCOMPLISHMENTS.md` is never deleted, only appended
- If the user wants to keep the local directory (e.g. PR not merged), use
  /workroom-close instead
