---
name: workroom-open
description: >
  Enter an existing workroom and restore its context from the work log. "Room"
  means workroom. Use when: (1) the user invokes /workroom-open; (2) asks to
  "open", "enter", "join", "go into", "switch to", "resume", "pick up",
  "continue", or "get back to" a workroom or room — e.g., "enter the auth room",
  "join workroom-ABC-123-fix-auth", "resume the auth fix workroom", "pick up where
  I left off on the memory leak"; (3) mentions a workroom name or ticket ID in a
  context that implies they want to continue that work. Do NOT use for creating
  new workrooms, listing, closing, leaving, or archiving.
---

# Workroom: Open

## Step 1: Run the Open Script

```bash
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/workroom.py" open \
  [--base-dir DIR] \
  <search term>
```

If `python3` is not found (Windows), run the same command with `python` or `py`.

The search term can be a workroom name, ticket ID, or any keyword.

## Step 2: Handle the Response

**Ambiguous match** (`"ambiguous": true`): list the matches and ask the user to
pick one, then re-run the script with a more specific term.

**No match** (`"error"` present): tell the user no workroom was found and suggest
running `/workroom-list` to see what's available.

**Single match**: proceed to Step 3.

## Step 3: Confirm and Orient

Present a clear resumption summary from the JSON:

```
Resuming workroom-ABC-123-fix-auth

Task:       Fix auth bug in api-gateway
Issue:      ABC-123 — JWT tokens not refreshing on expiry
Repo:       https://github.com/acme/api-gateway (branch: ABC-123-fix-auth)
Last entry: 2025-06-04 14:32
Phase:      Testing
Status:     In Progress

Ready to continue. Want me to pick up from the testing phase?
```

Wait for the user to confirm or redirect before taking any action.

## Step 4: Append Resumption Entry to WORKLOG.md

Once the user confirms, append to `<workroom_dir>/WORKLOG.md`:

```markdown
### YYYY-MM-DD HH:MM — Workroom resumed
**Status:** In Progress

---
```

Use the current local timestamp.

## Step 5: Continue the Workflow

Resume from `inferred_phase` in the JSON. If the phase is `"Unknown"`, ask:
> "It looks like you were in the middle of something. Want to pick up from
> [last status], or start fresh from a specific point?"
