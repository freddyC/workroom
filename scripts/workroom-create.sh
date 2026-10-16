#!/usr/bin/env bash
# workroom-create.sh
# Usage: workroom-create.sh [--base-dir DIR] [--ticket ID] [--repo URL]... <description words...>
#
# Outputs structured JSON for the LLM to read, then does all filesystem/git work.
# The LLM's job after running this: read the JSON, fetch issue details if needed,
# write WORKLOG.md and CLAUDE.md, guide the workflow phases.

set -eo pipefail

BASE_DIR="$PWD"
TICKET=""
REPOS=()
DESCRIPTION_WORDS=()

# --- Arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base-dir) BASE_DIR="$2"; shift 2 ;;
    --ticket)   TICKET="$2";   shift 2 ;;
    --repo)     REPOS+=("$2"); shift 2 ;;
    *)          DESCRIPTION_WORDS+=("$1"); shift ;;
  esac
done

if [[ ${#DESCRIPTION_WORDS[@]} -eq 0 ]]; then
  echo '{"error": "No description provided. Pass description words as positional arguments."}' >&2
  exit 1
fi

# --- Slug generation ---
DESCRIPTION="${DESCRIPTION_WORDS[*]}"
SLUG=$(echo "$DESCRIPTION" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -cs 'a-z0-9' '-' \
  | sed 's/^-//;s/-$//' \
  | cut -d'-' -f1-4)   # max 4 words

if [[ -n "$TICKET" ]]; then
  BASE_SLUG="${TICKET}-${SLUG}"
else
  BASE_SLUG="$SLUG"
fi

# --- Collision check ---
mkdir -p "$BASE_DIR"
WORKROOM_NAME="workroom-${BASE_SLUG}"
WORKROOM_DIR="${BASE_DIR}/${WORKROOM_NAME}"
SUFFIX=2
while [[ -d "$WORKROOM_DIR" ]]; do
  WORKROOM_NAME="workroom-${BASE_SLUG}-${SUFFIX}"
  WORKROOM_DIR="${BASE_DIR}/${WORKROOM_NAME}"
  (( SUFFIX++ ))
done

mkdir -p "$WORKROOM_DIR"

# --- Clone repos and create branches ---
CLONED=()
BRANCH_MAP=()

for REPO_URL in "${REPOS[@]}"; do
  REPO_NAME=$(basename "$REPO_URL" .git)
  REPO_DIR="$WORKROOM_DIR/$REPO_NAME"

  if ! git clone "$REPO_URL" "$REPO_DIR" >/dev/null 2>&1; then
    CLONED+=("{\"repo\": \"$REPO_URL\", \"status\": \"clone_failed\", \"path\": null, \"branch\": null}")
    continue
  fi

  # Detect default branch
  DEFAULT_BRANCH=$(git -C "$REPO_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null \
    | sed 's|refs/remotes/origin/||' || echo "main")

  # Branch name
  if [[ -n "$TICKET" ]]; then
    BRANCH="${TICKET}-${SLUG}"
  else
    BRANCH="$SLUG"
  fi

  git -C "$REPO_DIR" checkout -b "$BRANCH" "origin/$DEFAULT_BRANCH" 2>/dev/null \
    || git -C "$REPO_DIR" checkout -b "$BRANCH" 2>/dev/null

  CLONED+=("{\"repo\": \"$REPO_URL\", \"status\": \"ok\", \"path\": \"$REPO_DIR\", \"branch\": \"$BRANCH\", \"default_branch\": \"$DEFAULT_BRANCH\"}")
  BRANCH_MAP+=("$REPO_NAME=$BRANCH")
done

# --- Emit JSON ---
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
REPOS_JSON=$(printf '%s\n' "${CLONED[@]}" | paste -sd',' -)
TICKET_JSON=$([ -n "$TICKET" ] && echo "\"$TICKET\"" || echo "null")

cat <<EOF
{
  "workroom_name": "$WORKROOM_NAME",
  "workroom_dir": "$WORKROOM_DIR",
  "base_dir": "$BASE_DIR",
  "slug": "$SLUG",
  "ticket": $TICKET_JSON,
  "description": "$DESCRIPTION",
  "created_at": "$TIMESTAMP",
  "repos": [${REPOS_JSON}]
}
EOF
