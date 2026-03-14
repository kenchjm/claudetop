#!/bin/bash
# claudetop installer
# Copies claudetop.sh to ~/.claude/ and configures the status line + SessionEnd hook

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.claude/claudetop.sh"
PLUGIN_DIR="$HOME/.claude/claudetop.d"
SETTINGS="$HOME/.claude/settings.json"
STATS_DEST="/usr/local/bin/claudetop-stats"

echo "Installing claudetop..."

# 1. Copy main script
cp "$SCRIPT_DIR/claudetop.sh" "$DEST"
chmod +x "$DEST"
echo "  Copied claudetop.sh -> $DEST"

# 2. Create plugin directory
mkdir -p "$PLUGIN_DIR"
echo "  Created plugin directory: $PLUGIN_DIR"

# 3. Copy bundled plugins (only git-branch is enabled by default)
cp "$SCRIPT_DIR/plugins/git-branch.sh" "$PLUGIN_DIR/"
chmod +x "$PLUGIN_DIR/git-branch.sh"
echo "  Enabled plugin: git-branch"

# 4. Copy example plugins to _examples/
mkdir -p "$PLUGIN_DIR/_examples"
for f in "$SCRIPT_DIR/plugins/examples/"*.sh; do
  [ -f "$f" ] || continue
  cp "$f" "$PLUGIN_DIR/_examples/"
  chmod +x "$PLUGIN_DIR/_examples/$(basename "$f")"
done
echo "  Copied example plugins to $PLUGIN_DIR/_examples/"

# 5. Install claudetop-stats CLI
if [ -w "$(dirname "$STATS_DEST")" ]; then
  cp "$SCRIPT_DIR/claudetop-stats" "$STATS_DEST"
  chmod +x "$STATS_DEST"
  echo "  Installed claudetop-stats -> $STATS_DEST"
else
  echo "  Installing claudetop-stats (requires sudo)..."
  sudo cp "$SCRIPT_DIR/claudetop-stats" "$STATS_DEST"
  sudo chmod +x "$STATS_DEST"
  echo "  Installed claudetop-stats -> $STATS_DEST"
fi

# 6. Copy SessionEnd hook
HOOK_SRC="$SCRIPT_DIR/hooks/session-end.sh"
HOOK_DEST="$HOME/.claude/hooks/claudetop-session-end.sh"
mkdir -p "$HOME/.claude/hooks"
cp "$HOOK_SRC" "$HOOK_DEST"
chmod +x "$HOOK_DEST"
echo "  Copied session-end hook -> $HOOK_DEST"

# 7. Configure settings.json
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

if command -v jq &>/dev/null; then
  TMP=$(mktemp)

  # Add statusLine if not present
  if ! grep -q '"statusLine"' "$SETTINGS" 2>/dev/null; then
    jq '. + {"statusLine": {"type": "command", "command": "~/.claude/claudetop.sh", "padding": 1}}' "$SETTINGS" > "$TMP"
    mv "$TMP" "$SETTINGS"
    TMP=$(mktemp)
    echo "  Configured statusLine in settings.json"
  else
    echo "  statusLine already configured (skipped)"
  fi

  # Add SessionEnd hook if not present
  if ! grep -q 'claudetop-session-end' "$SETTINGS" 2>/dev/null; then
    jq --arg hook "$HOOK_DEST" '
      .hooks //= {} |
      .hooks.SessionEnd //= [] |
      .hooks.SessionEnd += [{"matcher": "", "hooks": [{"type": "command", "command": $hook}]}]
    ' "$SETTINGS" > "$TMP"
    mv "$TMP" "$SETTINGS"
    echo "  Added SessionEnd hook to settings.json"
  else
    echo "  SessionEnd hook already configured (skipped)"
  fi
else
  echo ""
  echo "  jq not found. Add these to $SETTINGS manually:"
  echo '    "statusLine": { "type": "command", "command": "~/.claude/claudetop.sh", "padding": 1 }'
  echo '    "hooks": { "SessionEnd": [{"matcher":"","hooks":[{"type":"command","command":"~/.claude/hooks/claudetop-session-end.sh"}]}] }'
fi

# 8. Copy pricing updater + fetch initial pricing
UPDATER_DEST="$HOME/.claude/update-claudetop-pricing.sh"
cp "$SCRIPT_DIR/update-pricing.sh" "$UPDATER_DEST"
chmod +x "$UPDATER_DEST"
cp "$SCRIPT_DIR/pricing.json" "$HOME/.claude/claudetop-pricing.json"
echo "  Installed pricing updater + initial pricing"

# Try to fetch latest pricing now
"$UPDATER_DEST" 2>/dev/null || true

# 9. Set up daily pricing update (cron job at 6am)
CRON_CMD="0 6 * * * $UPDATER_DEST >/dev/null 2>&1"
if ! crontab -l 2>/dev/null | grep -q "update-claudetop-pricing"; then
  (crontab -l 2>/dev/null || true; echo "$CRON_CMD") | crontab -
  echo "  Added daily pricing update cron (6am)"
else
  echo "  Daily pricing cron already configured (skipped)"
fi

echo ""
echo "Done! Restart Claude Code to activate claudetop."
echo ""
echo "Optional config (add to env or ~/.bashrc):"
echo "  export CLAUDETOP_DAILY_BUDGET=50    # Daily budget alert"
echo "  export CLAUDETOP_THEME=minimal      # compact|minimal|full"
echo "  export CLAUDETOP_TAG=my-feature     # Tag sessions for tracking"
echo ""
echo "View analytics:"
echo "  claudetop-stats          # Today"
echo "  claudetop-stats week     # This week"
echo "  claudetop-stats month    # This month"
echo "  claudetop-stats all      # All time"
echo "  claudetop-stats tag X    # Filter by tag"
echo ""
echo "Enable more plugins:"
echo "  cp $PLUGIN_DIR/_examples/spotify.sh $PLUGIN_DIR/"
echo "  cp $PLUGIN_DIR/_examples/gh-ci-status.sh $PLUGIN_DIR/"
echo "  cp $PLUGIN_DIR/_examples/meeting-countdown.sh $PLUGIN_DIR/"
