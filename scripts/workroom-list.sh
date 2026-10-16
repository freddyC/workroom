#!/usr/bin/env bash
# workroom-list.sh
# Usage: workroom-list.sh [--base-dir DIR] [--show-archived]
#
# Outputs JSON array of workrooms with name, task, status, last_updated.
# The LLM's job: format and present this to the user.

set -eo pipefail

BASE_DIR="$PWD"
SHOW_ARCHIVED=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir)      BASE_DIR="$2"; shift 2 ;;
    --show-archived) SHOW_ARCHIVED=true; shift ;;
    *) shift ;;
  esac
done

extract_worklog_field() {
  local file="$1" section="$2"
  awk "/^## ${section}/{found=1; next} found && /^## /{exit} found{print}" "$file" \
    | sed '/^[[:space:]]*$/d' | head -5 | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g;s/^ //;s/ $//'
}

extract_last_status() {
  local file="$1"
  grep -E '^\*\*Status:\*\*' "$file" | tail -1 | sed 's/\*\*Status:\*\* *//'
}

extract_last_entry_date() {
  local file="$1"
  grep -E '^### [0-9]{4}-[0-9]{2}-[0-9]{2}' "$file" | tail -1 \
    | sed 's/^### //' | cut -d' ' -f1,2
}

collect_workrooms() {
  local dir="$1" kind="$2"
  local results=()

  while IFS= read -r -d '' workroom_dir; do
    local name
    name=$(basename "$workroom_dir")
    local log="$workroom_dir/WORKLOG.md"

    if [[ ! -f "$log" ]]; then
      results+=("{\"name\": \"$name\", \"kind\": \"$kind\", \"task\": null, \"status\": \"no log\", \"last_updated\": null, \"path\": \"$workroom_dir\"}")
      continue
    fi

    local task status last_updated
    task=$(extract_worklog_field "$log" "Task")
    status=$(extract_last_status "$log")
    last_updated=$(extract_last_entry_date "$log")

    # Escape double quotes for JSON
    task=$(echo "$task" | sed 's/"/\\"/g')
    status=$(echo "$status" | sed 's/"/\\"/g')

    results+=("{\"name\": \"$name\", \"kind\": \"$kind\", \"task\": \"$task\", \"status\": \"${status:-unknown}\", \"last_updated\": \"${last_updated:-}\", \"path\": \"$workroom_dir\"}")
  done < <(find "$dir" -maxdepth 1 -type d -name "workroom-*" -print0 2>/dev/null | sort -z)

  [[ ${#results[@]} -gt 0 ]] && printf '%s\n' "${results[@]}"
}

ACTIVE_RESULTS=()
ARCHIVED_RESULTS=()

if [[ -d "$BASE_DIR" ]]; then
  while IFS= read -r line; do
    [[ -n "$line" ]] && ACTIVE_RESULTS+=("$line")
  done < <(collect_workrooms "$BASE_DIR" "active")
fi

if [[ "$SHOW_ARCHIVED" == true && -d "$BASE_DIR/workroom-archive" ]]; then
  ACC_FILE="$BASE_DIR/workroom-archive/ACCOMPLISHMENTS.md"
  if [[ -f "$ACC_FILE" ]]; then
    while IFS= read -r line; do
      if [[ "$line" =~ ^##\ ([0-9-]+)\ —\ (.+)$ ]]; then
        local_date="${BASH_REMATCH[1]}"
        summary="${BASH_REMATCH[2]}"
        summary=$(echo "$summary" | sed 's/"/\\"/g')
        ARCHIVED_RESULTS+=("{\"name\": \"archived\", \"kind\": \"archived\", \"task\": \"$summary\", \"status\": \"Archived\", \"last_updated\": \"$local_date\", \"path\": null}")
      fi
    done < "$ACC_FILE"
  fi
fi

COUNT=${#ACTIVE_RESULTS[@]}
ARCHIVE_COUNT=${#ARCHIVED_RESULTS[@]}
TOTAL=$((COUNT + ARCHIVE_COUNT))

if [[ $TOTAL -eq 0 ]]; then
  echo "{\"base_dir\": \"$BASE_DIR\", \"count\": 0, \"archive_count\": 0, \"workrooms\": []}"
  exit 0
fi

ITEMS=""
[[ $COUNT -gt 0 ]] && ITEMS=$(printf '%s\n' "${ACTIVE_RESULTS[@]}")
if [[ $ARCHIVE_COUNT -gt 0 ]]; then
  ARCHIVED=$(printf '%s\n' "${ARCHIVED_RESULTS[@]}")
  [[ -n "$ITEMS" ]] && ITEMS="$ITEMS"$'\n'"$ARCHIVED" || ITEMS="$ARCHIVED"
fi
ITEMS=$(echo "$ITEMS" | paste -sd',' -)
echo "{\"base_dir\": \"$BASE_DIR\", \"count\": $COUNT, \"archive_count\": $ARCHIVE_COUNT, \"workrooms\": [$ITEMS]}"
