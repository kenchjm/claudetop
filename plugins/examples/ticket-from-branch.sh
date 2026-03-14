#!/bin/bash
# Plugin: Parse ticket/issue number from git branch name

set -euo pipefail

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""')
[ -z "$CWD" ] && exit 0

cd "$CWD" 2>/dev/null || exit 0

command -v git >/dev/null 2>&1 || exit 0

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -z "$BRANCH" ] && exit 0

# Skip trunk branches
case "$BRANCH" in
  main|master|develop|development|trunk) exit 0 ;;
esac

# Strip common prefixes: feat/, fix/, feature/, chore/, hotfix/, etc.
STRIPPED=$(echo "$BRANCH" | sed 's|^[a-z]*/||')

TICKET=""

# Pattern 1: UPPERCASE-NUMBER (e.g. PROJ-123, JIRA-456)
if echo "$STRIPPED" | grep -qE '^[A-Z]+-[0-9]+'; then
  TICKET=$(echo "$STRIPPED" | grep -oE '^[A-Z]+-[0-9]+')

# Pattern 2: UPPERCASE-NUMBER anywhere at start of original branch (e.g. PROJ-123-description)
elif echo "$BRANCH" | grep -qE '(^|/)[A-Z]+-[0-9]+'; then
  TICKET=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' | head -1)

# Pattern 3: Leading numeric ID (e.g. 123-description, feature/123-description)
elif echo "$STRIPPED" | grep -qE '^[0-9]+-'; then
  NUM=$(echo "$STRIPPED" | grep -oE '^[0-9]+')
  TICKET="#${NUM}"

# Pattern 4: Bare numeric (e.g. feature/123)
elif echo "$STRIPPED" | grep -qE '^[0-9]+$'; then
  TICKET="#${STRIPPED}"
fi

[ -z "$TICKET" ] && exit 0

printf "\033[90m%s\033[0m" "$TICKET"
