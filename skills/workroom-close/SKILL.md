---
name: workroom-close
description: >
  Pause work on a workroom and safely record stopping state, without archiving or
  deleting it. Use when: (1) the user invokes /workroom-close; (2) says "close this
  workroom", "I'm done for now", "pause this workroom", "save my progress and stop",
  "wrap up for today", or any phrasing indicating they want to stop current work
  while keeping the workroom available to resume later. Do NOT use when the user
  wants to permanently archive or delete a workroom — use workroom-archive for that.
---

# Workroom: Close

## Step 1: Run the Close Script (Check Phase)

Run without `--commit` or `--stash` first to see what state the repos are in:

```bash
bash "$(dirname "$0")/../../scripts/workroom-close.sh" \
  [--base-dir DIR] \
  [--workroom NAME]
```

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
bash "$(dirname "$0")/../../scripts/workroom-close.sh" \
  --workroom NAME --commit --summary "WIP: token refresh logic, tests failing"

# Stash:
bash "$(dirname "$0")/../../scripts/workroom-close.sh" \
  --workroom NAME --stash --summary "Pausing mid-implementation"

# Leave as-is: no second run needed, just note it
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
