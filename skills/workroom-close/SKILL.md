---
name: workroom-close
description: >
  Leave a workroom for now: record stopping state in its work log, without
  archiving or deleting it. "Room" means workroom. Use when: (1) the user invokes
  /workroom-close; (2) says "close", "leave", "exit", "step out of", or "pause"
  this workroom or room, "I'm done for now", "save my progress and stop", "wrap up
  for today", or any phrasing indicating they want to stop current work while
  keeping the workroom available to come back to. Do NOT use when the user wants
  to permanently archive or delete a workroom — use workroom-archive for that.
allowed-tools:
  - Bash(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(python "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(py "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
---

# Workroom: Close

## Step 1: Run the Close Script (Check Phase)

Run without `--commit`, `--stash` or `--leave` first to see what state the repos
are in. Pass `--summary` now: if nothing needs a decision, this run writes the
log entry.

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" close \
  [--base-dir DIR] \
  [--workroom NAME] \
  --summary "Where things stand and what's next"
```

On Windows, run the same command with `python` (or `py`): `python3` there is
usually the Microsoft Store stub, which fails.

If the user's cwd is inside a workroom, `--workroom` can be omitted.

## Step 2: Handle Uncommitted Changes

If `"needs_decision": true`, present the situation per repo and ask:

> "There are uncommitted changes in [repo-name]:
>   M  src/auth/token.js
>   M  tests/auth.test.js
>
> Want me to commit them, stash them, or leave them as-is?"

Then re-run with the chosen flag and a summary of the stopping point:

```bash
# Commit:
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" close \
  --workroom NAME --commit --summary "WIP: token refresh logic, tests failing"

# Stash:
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" close \
  --workroom NAME --stash --summary "Pausing mid-implementation"

# Leave as-is (still logs the stop):
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" close \
  --workroom NAME --leave --summary "Mid-refactor, changes left uncommitted"
```

If `"needs_decision": false`, the script already appended the log entry — skip
to Step 3.

## Step 3: Confirm

```
Workroom paused: workroom-ABC-123-fix-auth

Changes: committed / stashed / left as-is
Log:     Updated with stopping point

To resume later, use /workroom-open.
```

## Notes

- The workroom directory is left fully intact — nothing is deleted
- Do not push branches unless the user explicitly asks
- If the user says "archive" or "I'm done permanently", redirect to /workroom-archive
