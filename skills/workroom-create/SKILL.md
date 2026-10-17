---
name: workroom-create
description: >
  Create a new isolated workroom directory for focused development work. Use when:
  (1) the user invokes /workroom-create or /workroom; (2) asks to "start a workroom",
  "create a workroom", "set up a workspace", or "new workroom"; (3) describes a task
  that implies beginning focused work on a specific problem — e.g., "let's work on
  fixing the auth bug in api-gateway", "I need to investigate the memory leak in
  search-service", "spin up a workspace for the ABC-123 ticket"; (4) provides a
  repo URL and a task description together. Do NOT use for listing, opening, closing,
  or archiving existing workrooms.
allowed-tools:
  - Bash(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(python "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
  - Bash(py "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" *)
---

# Workroom: Create

## Step 1: Parse Inputs

From the user's prompt extract:
- **Description** (required): the task or problem statement
- **Repo URLs** (optional): any GitHub/git URLs
- **Ticket/Issue** (optional): `#123`, `PROJ-456`, or issue tracker URL
- **Base dir** (optional): defaults to current working directory

If the description is missing, ask before proceeding.

## Step 2: Run the Create Script

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" create \
  [--base-dir DIR] \
  [--ticket TICKET_ID] \
  [--repo URL] \         # repeat for each repo
  <description words...>
```

If `python3` is not found (Windows), run the same command with `python` or `py`.

Read the JSON output. It contains `workroom_dir`, `workroom_name`, `slug`,
`created_at`, `worklog`, `claude_md`, `entry_template` and `repos` (each with
`path`, `branch`, `status`).

The script has already written `WORKLOG.md` and `CLAUDE.md` from the templates
(run the `workroom-check` skill to see or change them). Don't rewrite them.

If any repo has `"status": "clone_failed"`, tell the user and ask how to proceed.

## Step 3: Fetch Issue Details (if ticket provided)

- **GitHub**: `gh issue view <number> --repo <org/repo> --json title,body,labels`
- **Jira**: `mcp__atlassian-mcp__jira_get_issue` if available
- **Other URL**: record as-is, skip fetching

If you fetched details, replace the body of the `## Issue` section in
`WORKLOG.md` (it holds just the ticket ID) with the ID, URL, title and a short
summary. Leave the other sections as the script wrote them.

## Step 4: Confirm

```
Workroom created: <workroom_dir>
Directory:    <workroom_name>
Repositories: <repo names>     (if any)
Branch:       <branch>         (per repo)
Issue:        <ID — title>     (if linked)

Ready to start. What would you like to do first?
```

## Workflow Phases

After setup, guide through: **Planning → Implementation → Testing → Review**.
Suggest the next phase when the current one reaches a natural stopping point.
Adapt the flow to task scope — quick fixes skip planning; research skips testing.

If new information invalidates the plan, surface it immediately and offer to replan.
Document any pivot in WORKLOG.md under a new `## Design` revision entry.

Append to WORKLOG.md as work progresses, one entry per step, in the format of
the template at `entry_template` from the script output: fill `{{timestamp}}`
(YYYY-MM-DD HH:MM), `{{task}}`, `{{changes}}`, `{{files}}` and `{{status}}`
(Complete / In Progress / Blocked). Keep each entry's `### <date>` heading and
`**Status:**` line; `workroom-open` and `workroom-list` read them.
