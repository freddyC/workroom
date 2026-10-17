---
name: workroom-list
description: >
  List workrooms and their status, and say which one the user is in. "Room"
  means workroom. Use when: (1) the user invokes /workroom-list; (2) asks "what
  workrooms do I have?", "show my workrooms", "list workrooms", "what am I working
  on?"; (3) asks which room they are in — "what room am I in?", "which workroom
  is this?", "where am I?", "am I in a workroom?". Do NOT use for creating,
  opening, closing, or archiving workrooms.
allowed-tools:
  - Bash(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(python "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(py "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
---

# Workroom: List

Run the script and show its output exactly as printed, in a code block. Don't
rebuild or reword it; the script already formats it.

- **Which room am I in** ("what room am I in?", "where am I?"):
  ```bash
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" list --text --current
  ```
- **List workrooms** (add `--show-archived` only if the user asked for archived ones):
  ```bash
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" list --text [--base-dir DIR] [--show-archived]
  ```

If `python3` is not found (Windows), run the same command with `python` or `py`.

The commands find the folder that holds the workrooms on their own, even from
inside one. For details on one workroom, read its `WORKLOG.md` and summarize it.
Without `--text` the script prints JSON (`base_dir`, `current`, `count`,
`workrooms`) for when you need the fields themselves.
