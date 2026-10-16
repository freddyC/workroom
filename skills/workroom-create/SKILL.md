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
bash "$(dirname "$0")/../../scripts/workroom-create.sh" \
  [--base-dir DIR] \
  [--ticket TICKET_ID] \
  [--repo URL] \         # repeat for each repo
  <description words...>
```

Read the JSON output. It contains `workroom_dir`, `workroom_name`, `slug`,
`created_at`, and `repos` (each with `path`, `branch`, `status`).

If any repo has `"status": "clone_failed"`, tell the user and ask how to proceed.

## Step 3: Fetch Issue Details (if ticket provided)

- **GitHub**: `gh issue view <number> --repo <org/repo> --json title,body,labels`
- **Jira**: `mcp__atlassian-mcp__jira_get_issue` if available
- **Other URL**: record as-is, skip fetching

## Step 4: Write WORKLOG.md

Write to `<workroom_dir>/WORKLOG.md`:

```markdown
# Workroom Log

Created: <created_at>
Directory: <workroom_name>

## Task

<user's description>

## Repositories

<repo URLs, one per line — or "None">

## Issue

<ticket ID, URL, title, summary — or "None">

## Work Log

### <created_at> — Workroom created
**Branch:** <branch from script output, or "N/A">
**Status:** Ready to start

---
```

## Step 5: Write CLAUDE.md

Write to `<workroom_dir>/CLAUDE.md`:

```markdown
# Workroom: <workroom_name>

All work in this session must stay within this directory (<workroom_dir>).

- Save all files, temp files, scripts, and artifacts inside this workroom
- Do not write outside this workroom unless the user explicitly confirms
- Reading files outside is fine for reference
- Cloned repos live at this directory's root level
```

## Step 6: Confirm

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

Append to WORKLOG.md as work progresses:
```markdown
### YYYY-MM-DD HH:MM — <Task>
**What:** <changes>
**Files:** <affected files>
**Status:** Complete / In Progress / Blocked

---
```
