---
name: workroom-archive
description: >
  Permanently archive and clean up a completed workroom, preserving its work log
  in the archive. Use when: (1) the user invokes /workroom-archive; (2) says
  "archive this workroom", "I'm done with this workroom", "clean up the workroom",
  "the PR is merged, archive it", "delete the workroom", or any phrasing indicating
  the work is complete and the local directory should be removed. Do NOT use when
  the user just wants to pause — use workroom-close for that.
allowed-tools:
  - Bash(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(python "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(py "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
---

# Workroom: Archive

Two-phase process: checklist first, delete only after explicit user confirmation.

## Step 1: Run the Archive Script (Checklist Phase)

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" archive \
  [--base-dir DIR] \
  [--workroom NAME]
```

On Windows, run the same command with `python` (or `py`): `python3` there is
usually the Microsoft Store stub, which fails.

If the user's cwd is inside a workroom, `--workroom` can be omitted.

## Step 2: Present the Checklist

Read the JSON (`"phase": "checklist"`). If `"all_clean": false`, surface every
repo warning and every entry in `loose_files` before proceeding. Archiving keeps
only `WORKLOG.md`: everything else in the folder is deleted.

> "Before archiving, a few things would be lost:
>   ⚠ api-gateway: uncommitted changes
>   ⚠ api-gateway: 1 commits on no remote
>   ⚠ api-gateway: 2 stashes
>   ⚠ loose files: analysis.md, scripts/
>
> Want me to commit and push, and move or keep the loose files, before archiving?"

`commits on no remote` counts commits on any local branch that no remote has,
including branches with no upstream. Handle each item (commit, push, pop or drop
stashes, move loose files out) before continuing.

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
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" archive \
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
