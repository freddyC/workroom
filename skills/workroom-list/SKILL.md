---
name: workroom-list
description: >
  List all existing workrooms and their current status. Use when: (1) the user
  invokes /workroom-list; (2) asks "what workrooms do I have?", "show my workrooms",
  "list workrooms", "what am I working on?", or any similar query about seeing
  active or existing workrooms. Do NOT use for creating, opening, closing, or
  archiving workrooms.
---

# Workroom: List

## Step 1: Run the List Script

```bash
bash "$(dirname "$0")/../../scripts/workroom-list.sh" \
  [--base-dir DIR] \
  [--show-archived]     # only if user asked to see archived workrooms
```

## Step 2: Present the Results

Read the JSON. Format it as a clean summary:

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
