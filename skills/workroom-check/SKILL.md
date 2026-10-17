---
name: workroom-check
description: >
  Check and update the markdown files workrooms write (WORKLOG.md, CLAUDE.md,
  ACCOMPLISHMENTS.md) and the templates they come from. Use when: (1) the user
  invokes /workroom-check; (2) asks to "check my workrooms", "fix the work logs",
  "update the workroom templates", "change the WORKLOG format", "customize
  workrooms", or "add a section to every work log"; (3) a workroom script reports
  a missing section. Do NOT use for creating, opening, closing, listing, or
  archiving workrooms.
allowed-tools:
  - Bash(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(python "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(py "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
---

# Workroom: Check

Workroom files are rendered from six templates: `WORKLOG.md`, `CLAUDE.md`,
`worklog-entry.md`, `worklog-paused.md`, `ACCOMPLISHMENTS.md` and
`accomplishment.md`. Each template uses `{{placeholders}}`; one nothing fills
(a section the user added) renders as `None`. A file of the same name in the
override folder (`$WORKROOM_TEMPLATES`, default `~/.claude/workroom/templates`)
replaces the plugin's copy.

## Step 1: Run the Check

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" check \
  [--base-dir DIR] \
  [--workroom NAME]
```

If `python3` is not found (Windows), run the same command with `python` or `py`.

The JSON has `templates` (each with `source`: `default` or `override`, and its
`path`), `template_problems`, and `workrooms`, each with its `files` and their
`status`: `ok`, `missing`, or `sections_missing` with the `missing` headings.

## Step 2: Report

```
Templates: 2 overridden (WORKLOG.md, CLAUDE.md), 4 default
Override folder: ~/.claude/workroom/templates

workroom-ABC-123-fix-auth
  WORKLOG.md  missing: ## Decisions
  CLAUDE.md   ok
workroom-search-latency
  all ok
```

Report each `template_problems` entry first: a WORKLOG.md template without
`## Task`, `## Issue`, `## Repositories` or `## Work Log` breaks `workroom-open`,
`workroom-list` and `workroom-archive`, which read those sections.

## Step 3: Fix (only if the user agrees)

Ask before changing any workroom. Then:

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" check --fix [--workroom NAME]
```

This writes a missing file from its template and adds each missing section,
with `None` as its body, just above `## Work Log`. Offer to fill in the new
sections from what you know about the workroom.

## Changing the Format

When the user wants a different format (a new section, other wording, a
different accomplishment line):

1. Copy the templates to the override folder, keeping any already there:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" check --init-templates
   ```
2. Edit the file in `templates_dir` from the output. Keep the four required
   WORKLOG.md headings, each entry's `### YYYY-MM-DD HH:MM — ...` heading and
   its `**Status:**` line.
3. Run the check again so existing workrooms pick up new sections (Step 3).

New workrooms use the edited templates from then on. To go back to a default,
delete that file from the override folder.
