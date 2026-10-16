---
name: workroom-list
description: >
  List workrooms and their status, and say which one the user is in. "Room"
  means workroom. Use when: (1) the user invokes /workroom-list; (2) asks "what
  workrooms do I have?", "show my workrooms", "list workrooms", "what am I working
  on?"; (3) asks which room they are in — "what room am I in?", "which workroom
  is this?", "where am I?", "am I in a workroom?". Do NOT use for creating,
  opening, closing, or archiving workrooms.
---

# Workroom: List

## Step 1: Run the List Script

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" list \
  [--base-dir DIR] \
  [--show-archived]     # only if user asked to see archived workrooms
```

If `python3` is not found (Windows), run the same command with `python` or `py`.

## Step 2: Present the Results

`current` is the workroom holding the current folder (it or any parent), or
`null` outside one. `base_dir` is the folder that holds the workrooms, even when
the command runs from inside one.

If the user asked which room they are in, answer with `current` alone:

```
You're in workroom-ABC-123-fix-auth — Fix auth bug in api-gateway [In Progress]
Last update: 2026-10-14 16:20
```

or, when `current` is `null`: `You're not in a workroom.` followed by the
active workrooms in `<base_dir>`, if any, so they can enter one.

Otherwise format the list as a clean summary, marking `current` with `(you're here)`:

```
Active workrooms (3):

  workroom-ABC-123-fix-auth     — Fix auth bug in api-gateway          [In Progress]
  workroom-memory-leak           — Investigate search-service memory     [Ready to start]
  workroom-add-dark-mode         — Add dark mode to dashboard            [Blocked]

<base_dir from JSON>
```

Sort order: the script returns workrooms sorted by name; present as-is.

If `count` is 0:
```
No workrooms found in <base_dir from JSON>.
Use /workroom-create to start one.
```

If the user asks for details on a specific workroom, read that workroom's full
`WORKLOG.md` and summarize it inline — don't run a separate script for this.

## Notes

- Show archived workrooms only if `--show-archived` was passed (user explicitly asked)
- If `"task": null`, show `(no log found)` in place of the task description
- Use `last_updated` from the JSON to show relative age if helpful ("3 days ago")
