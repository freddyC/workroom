#!/usr/bin/env bash
# workroom-open.sh
# Usage: workroom-open.sh [--base-dir DIR] <search-term>
#
# Finds a workroom by name/ticket/keyword, extracts full context from WORKLOG.md.
# Outputs JSON for the LLM to read and present to the user.
# The LLM's job: confirm with user, append resumption log entry, continue workflow.

set -eo pipefail

BASE_DIR="$PWD"
SEARCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir) BASE_DIR="$2"; shift 2 ;;
    *) SEARCH="$SEARCH $1"; shift ;;
  esac
done

SEARCH=$(echo "$SEARCH" | sed 's/^ //')

if [[ -z "$SEARCH" ]]; then
  echo '{"error": "No search term provided."}' >&2
  exit 1
fi

if [[ ! -d "$BASE_DIR" ]]; then
  echo "{\"error\": \"Base directory not found: $BASE_DIR\"}" >&2
  exit 1
fi

# --- Find matching workrooms ---
MATCHES=()
while IFS= read -r -d '' dir; do
  name=$(basename "$dir")
  if echo "$name" | grep -qi "$SEARCH"; then
    MATCHES+=("$dir")
  fi
done < <(find "$BASE_DIR" -maxdepth 1 -type d -name "workroom-*" -print0 | sort -z)

if [[ ${#MATCHES[@]} -eq 0 ]]; then
  # Try searching inside WORKLOG.md task descriptions too
  while IFS= read -r -d '' dir; do
    log="$dir/WORKLOG.md"
    if [[ -f "$log" ]] && grep -qi "$SEARCH" "$log"; then
      MATCHES+=("$dir")
    fi
  done < <(find "$BASE_DIR" -maxdepth 1 -type d -name "workroom-*" -print0 | sort -z)
fi

if [[ ${#MATCHES[@]} -eq 0 ]]; then
  echo "{\"error\": \"No workroom found matching: $SEARCH\", \"search\": \"$SEARCH\", \"base_dir\": \"$BASE_DIR\"}"
  exit 0
fi

if [[ ${#MATCHES[@]} -gt 1 ]]; then
  # Return all matches so LLM can ask user to disambiguate
  MATCH_LIST=$(printf '"%s"\n' "${MATCHES[@]}" | paste -sd',' -)
  echo "{\"ambiguous\": true, \"search\": \"$SEARCH\", \"matches\": [$MATCH_LIST]}"
  exit 0
fi

# --- Single match: extract full context ---
WORKROOM_DIR="${MATCHES[0]}"
WORKROOM_NAME=$(basename "$WORKROOM_DIR")
LOG="$WORKROOM_DIR/WORKLOG.md"

if [[ ! -f "$LOG" ]]; then
  echo "{\"error\": \"Workroom found but WORKLOG.md is missing\", \"workroom_dir\": \"$WORKROOM_DIR\"}"
  exit 0
fi

extract_section() {
  local section="$1"
  awk "/^## ${section}/{found=1; next} found && /^## /{exit} found{print}" "$LOG" \
    | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|$//'
}

extract_last_log_entry() {
  # Get the last ### block from Work Log section
  awk '/^## Work Log/{found=1; next} found && /^## /{exit} found{print}' "$LOG" \
    | awk '/^### /{block=""} {block=block"\n"$0} END{print block}' \
    | sed '/^[[:space:]]*$/d' | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|$//'
}

extract_last_status() {
  grep -E '^\*\*Status:\*\*' "$LOG" | tail -1 | sed 's/\*\*Status:\*\* *//' | sed 's/"/\\"/g'
}

extract_last_date() {
  grep -E '^### [0-9]{4}-[0-9]{2}-[0-9]{2}' "$LOG" | tail -1 | sed 's/^### //' | cut -d' ' -f1,2
}

infer_phase() {
  local status="$1"
  case "${status,,}" in
    *plan*|*design*|*ready*) echo "Planning" ;;
    *implement*|*progress*) echo "Implementation" ;;
    *test*)                 echo "Testing" ;;
    *review*|*pr*|*done*)   echo "Review" ;;
    *block*)                echo "Blocked" ;;
    *pause*)                echo "Paused" ;;
    *)                      echo "Unknown" ;;
  esac
}

TASK=$(extract_section "Task")
REPOS=$(extract_section "Repositories")
ISSUE=$(extract_section "Issue")
DESIGN=$(extract_section "Design")
LAST_ENTRY=$(extract_last_log_entry)
LAST_STATUS=$(extract_last_status)
LAST_DATE=$(extract_last_date)
PHASE=$(infer_phase "$LAST_STATUS")
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')

cat <<EOF
{
  "workroom_name": "$WORKROOM_NAME",
  "workroom_dir": "$WORKROOM_DIR",
  "resumed_at": "$TIMESTAMP",
  "context": {
    "task": "$TASK",
    "repositories": "$REPOS",
    "issue": "$ISSUE",
    "design": "$DESIGN"
  },
  "last_entry": {
    "date": "$LAST_DATE",
    "status": "$LAST_STATUS",
    "content": "$LAST_ENTRY"
  },
  "inferred_phase": "$PHASE"
}
EOF
