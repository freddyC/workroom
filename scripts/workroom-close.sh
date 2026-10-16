#!/usr/bin/env bash
# workroom-close.sh
# Usage: workroom-close.sh [--base-dir DIR] [--workroom NAME] [--commit] [--stash] [--summary "text"]
#
# Checks git status of all repos in the workroom, optionally commits or stashes,
# then appends a closing entry to WORKLOG.md.
# The LLM's job: read the JSON, present uncommitted-change decisions to user if
# --commit/--stash not passed, then call again with the chosen action.

set -eo pipefail

BASE_DIR="$PWD"
WORKROOM_NAME=""
DO_COMMIT=false
DO_STASH=false
SUMMARY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir)   BASE_DIR="$2";    shift 2 ;;
    --workroom)   WORKROOM_NAME="$2"; shift 2 ;;
    --commit)     DO_COMMIT=true;   shift ;;
    --stash)      DO_STASH=true;    shift ;;
    --summary)    SUMMARY="$2";     shift 2 ;;
    *) shift ;;
  esac
done

# --- Resolve workroom dir ---
if [[ -z "$WORKROOM_NAME" ]]; then
  # Try to detect from cwd
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

TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
REPO_STATUSES=()
ACTION_TAKEN="none"

# --- Check each repo ---
while IFS= read -r -d '' repo_dir; do
  repo_name=$(basename "$repo_dir")
  dirty=$(git -C "$repo_dir" status --short 2>/dev/null)
  unpushed=$(git -C "$repo_dir" log '@{u}..' --oneline 2>/dev/null | wc -l | tr -d ' ')
  stashes=$(git -C "$repo_dir" stash list 2>/dev/null | wc -l | tr -d ' ')
  branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

  has_changes=false
  [[ -n "$dirty" ]] && has_changes=true

  if [[ "$has_changes" == true ]]; then
    if [[ "$DO_COMMIT" == true ]]; then
      commit_msg="WIP: ${SUMMARY:-pausing workroom $WORKROOM_NAME}"
      git -C "$repo_dir" add -A
      git -C "$repo_dir" commit -m "$commit_msg" 2>/dev/null
      ACTION_TAKEN="committed"
      dirty=""
    elif [[ "$DO_STASH" == true ]]; then
      git -C "$repo_dir" stash push -m "workroom-close: $TIMESTAMP" 2>/dev/null
      ACTION_TAKEN="stashed"
      dirty=""
      stashes=$(git -C "$repo_dir" stash list 2>/dev/null | wc -l | tr -d ' ')
    fi
  fi

  dirty_escaped=$(echo "$dirty" | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|$//')
  REPO_STATUSES+=("{\"repo\": \"$repo_name\", \"branch\": \"$branch\", \"has_changes\": $has_changes, \"uncommitted\": \"$dirty_escaped\", \"unpushed_commits\": $unpushed, \"stash_count\": $stashes, \"action_taken\": \"$ACTION_TAKEN\"}")
done < <(find "$WORKROOM_DIR" -maxdepth 1 -type d -print0 | sort -z | while IFS= read -r -d '' d; do
  [[ -d "$d/.git" ]] && printf '%s\0' "$d"
done)

# --- Determine if there are uncommitted changes needing a decision ---
REPOS_JSON=$(printf '%s\n' "${REPO_STATUSES[@]}" | paste -sd',' -)
NEEDS_DECISION=false
for status in "${REPO_STATUSES[@]}"; do
  if echo "$status" | grep -q '"has_changes": true'; then
    NEEDS_DECISION=true
    break
  fi
done

# --- Append close entry to WORKLOG.md only when state is resolved ---
# Skip if there are uncommitted changes the user hasn't decided on yet
LOG="$WORKROOM_DIR/WORKLOG.md"
LOG_UPDATED=false
if [[ "$NEEDS_DECISION" == false && -f "$LOG" ]]; then
  SUMMARY_LINE="${SUMMARY:-<fill in what you were working on>}"
  cat >> "$LOG" << EOF

### $TIMESTAMP — Workroom paused
**What:** $SUMMARY_LINE
**Status:** Paused — ready to resume

---
EOF
  LOG_UPDATED=true
fi

cat <<EOF
{
  "workroom_name": "$WORKROOM_NAME",
  "workroom_dir": "$WORKROOM_DIR",
  "closed_at": "$TIMESTAMP",
  "log_updated": $LOG_UPDATED,
  "needs_decision": $NEEDS_DECISION,
  "repos": [${REPOS_JSON:-}]
}
EOF
