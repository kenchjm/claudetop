#!/bin/bash
# Plugin: GitHub CI status for current git branch

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[ -z "$CWD" ] && exit 0

cd "$CWD" 2>/dev/null || exit 0

command -v gh >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -z "$BRANCH" ] && exit 0

# Per-branch cache keyed by a short hash of branch name
BRANCH_HASH=$(echo -n "$BRANCH" | md5 2>/dev/null || echo -n "$BRANCH" | md5sum 2>/dev/null | cut -c1-8)
CACHE="/tmp/claudetop-ci-${BRANCH_HASH}"
CACHE_AGE=60

if [ -f "$CACHE" ]; then
  AGE=$(( $(date +%s) - $(stat -f%m "$CACHE" 2>/dev/null || stat -c%Y "$CACHE" 2>/dev/null || echo 0) ))
  if [ "$AGE" -lt "$CACHE_AGE" ]; then
    CACHED=$(cat "$CACHE")
    [ -n "$CACHED" ] && printf "%s" "$CACHED"
    exit 0
  fi
fi

RUN_JSON=$(gh run list --branch "$BRANCH" --limit 1 --json status,conclusion 2>/dev/null) || exit 0
[ -z "$RUN_JSON" ] || [ "$RUN_JSON" = "[]" ] && exit 0

STATUS=$(echo "$RUN_JSON" | jq -r '.[0].status // ""')
CONCLUSION=$(echo "$RUN_JSON" | jq -r '.[0].conclusion // ""')

[ -z "$STATUS" ] && exit 0

if [ "$CONCLUSION" = "success" ]; then
  OUTPUT=$(printf "\033[32mCI \xe2\x9c\x93\033[0m")
elif [ "$CONCLUSION" = "failure" ] || [ "$CONCLUSION" = "cancelled" ]; then
  OUTPUT=$(printf "\033[31mCI \xe2\x9c\x97\033[0m")
elif [ "$STATUS" = "in_progress" ] || [ "$STATUS" = "queued" ] || [ "$STATUS" = "waiting" ]; then
  OUTPUT=$(printf "\033[33mCI \xe2\x80\xa6\033[0m")
else
  exit 0
fi

echo -n "$OUTPUT" > "$CACHE"
printf "%s" "$OUTPUT"
