#!/usr/bin/env bash
# workroom-archive.sh
# Usage: workroom-archive.sh [--base-dir DIR] [--workroom NAME]
#                            [--outcome "text"] [--pr-url URL]
#                            [--confirm-delete]
#
# Two-phase:
#   Phase 1 (no --confirm-delete): runs pre-archive checklist, outputs JSON.
#     The LLM reads this and asks user to confirm deletion.
#   Phase 2 (--confirm-delete): moves WORKLOG.md, updates ACCOMPLISHMENTS.md,
#     deletes workroom directory.

set -eo pipefail

BASE_DIR="$PWD"
WORKROOM_NAME=""
OUTCOME=""
PR_URL=""
CONFIRM_DELETE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir)       BASE_DIR="$2";      shift 2 ;;
    --workroom)       WORKROOM_NAME="$2"; shift 2 ;;
    --outcome)        OUTCOME="$2";       shift 2 ;;
    --pr-url)         PR_URL="$2";        shift 2 ;;
    --confirm-delete) CONFIRM_DELETE=true; shift ;;
    *) shift ;;
  esac
done

# --- Resolve workroom ---
if [[ -z "$WORKROOM_NAME" ]]; then
  CWD=$(pwd)
  if [[ "$CWD" == "$BASE_DIR/workroom-"* ]]; then
    WORKROOM_NAME=$(basename "$CWD")
  else
    echo '{"error": "No workroom specified and cwd is not inside a workroom. Pass --workroom NAME."}' >&2
    exit 1
  fi
fi

WORKROOM_DIR="$BASE_DIR/$WORKROOM_NAME"
if [[ ! -d "$WORKROOM_DIR" ]]; then
  echo "{\"error\": \"Workroom not found: $WORKROOM_DIR\"}" >&2
  exit 1
fi

LOG="$WORKROOM_DIR/WORKLOG.md"
ARCHIVE_DIR="$BASE_DIR/workroom-archive"
TODAY=$(date '+%Y-%m-%d')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

# --- Extract task/ticket from WORKLOG.md ---
extract_field() {
  local section="$1"
  awk "/^## ${section}/{found=1; next} found && /^## /{exit} found{print}" "$LOG" 2>/dev/null \
    | sed '/^[[:space:]]*$/d' | head -3 | tr '\n' ' ' | sed 's/  */ /g;s/^ //;s/ $//' | sed 's/"/\\"/g'
}

TASK=$(extract_field "Task")
TICKET=$(extract_field "Issue" | grep -oE '[A-Z]+-[0-9]+|#[0-9]+' | head -1 || echo "N/A")
[[ -z "$TICKET" ]] && TICKET="N/A"

# Derive topic slug from workroom name (strip "workroom-" prefix and ticket prefix)
TOPIC_SLUG=$(echo "$WORKROOM_NAME" | sed 's/^workroom-//' | sed "s/^${TICKET}-//i" | sed 's/-/_/g')
ARCHIVE_LOG_NAME="WORKLOG-${TODAY}-${TOPIC_SLUG}.md"

# --- Phase 1: Pre-archive checklist ---
REPO_CHECKS=()
ALL_CLEAN=true

while IFS= read -r -d '' repo_dir; do
  repo_name=$(basename "$repo_dir")
  branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  dirty=$(git -C "$repo_dir" status --short 2>/dev/null)
  unpushed=$(git -C "$repo_dir" log '@{u}..' --oneline 2>/dev/null | wc -l | tr -d ' ')
  remote=$(git -C "$repo_dir" remote get-url origin 2>/dev/null | sed 's/"/\\"/g' || echo "")

  is_clean=true
  warnings=()
  [[ -n "$dirty" ]]       && { is_clean=false; ALL_CLEAN=false; warnings+=("uncommitted changes"); }
  [[ "$unpushed" -gt 0 ]] && { is_clean=false; ALL_CLEAN=false; warnings+=("$unpushed unpushed commits"); }

  [[ ${#warnings[@]} -gt 0 ]] && WARN_JSON=$(printf '"%s",' "${warnings[@]}" | sed 's/,$//') || WARN_JSON=""
  REPO_CHECKS+=("{\"repo\": \"$repo_name\", \"branch\": \"$branch\", \"remote\": \"$remote\", \"clean\": $is_clean, \"warnings\": [$WARN_JSON]}")
done < <(find "$WORKROOM_DIR" -maxdepth 1 -type d -print0 | sort -z | while IFS= read -r -d '' d; do
  [[ -d "$d/.git" ]] && printf '%s\0' "$d"
done)

REPOS_JSON=$(printf '%s\n' "${REPO_CHECKS[@]}" | paste -sd',' -)

if [[ "$CONFIRM_DELETE" == false ]]; then
  # Phase 1 only — return checklist for LLM to review with user
  cat <<EOF
{
  "phase": "checklist",
  "workroom_name": "$WORKROOM_NAME",
  "workroom_dir": "$WORKROOM_DIR",
  "task": "$TASK",
  "ticket": "$TICKET",
  "all_clean": $ALL_CLEAN,
  "archive_log_name": "$ARCHIVE_LOG_NAME",
  "repos": [${REPOS_JSON:-}]
}
EOF
  exit 0
fi

# --- Phase 2: Perform archive ---
mkdir -p "$ARCHIVE_DIR"

# Move WORKLOG.md
if [[ -f "$LOG" ]]; then
  mv "$LOG" "$ARCHIVE_DIR/$ARCHIVE_LOG_NAME"
  LOG_MOVED=true
else
  LOG_MOVED=false
fi

# Append to ACCOMPLISHMENTS.md
ACC_FILE="$ARCHIVE_DIR/ACCOMPLISHMENTS.md"
OUTCOME_LINE="${OUTCOME:-$TASK}"
PR_LINE="${PR_URL:+$PR_URL}"
[[ -z "$PR_LINE" ]] && PR_LINE="N/A"

if [[ ! -f "$ACC_FILE" ]]; then
  cat > "$ACC_FILE" << 'HEADER'
# Workroom Accomplishments

A running index of completed workrooms.

---
HEADER
fi

cat >> "$ACC_FILE" << EOF

## $TODAY — $OUTCOME_LINE
**Ticket:** $TICKET
**Outcome:** $OUTCOME_LINE
**PR:** $PR_LINE
**Worklog:** [$ARCHIVE_LOG_NAME]($ARCHIVE_LOG_NAME)

---
EOF

# Delete workroom directory
rm -rf "$WORKROOM_DIR"

cat <<EOF
{
  "phase": "complete",
  "workroom_name": "$WORKROOM_NAME",
  "archived_at": "$TIMESTAMP",
  "log_moved": $LOG_MOVED,
  "archive_log": "$ARCHIVE_DIR/$ARCHIVE_LOG_NAME",
  "accomplishments_updated": true,
  "deleted": true
}
EOF
