#!/bin/bash
# Plugin: Time until next calendar event (macOS)
# Requires: icalBuddy (brew install ical-buddy) or Calendar.app via osascript

set -euo pipefail

CACHE="/tmp/claudetop-meeting-cache"
CACHE_AGE=120
LOOKAHEAD_MINUTES=120

if [ -f "$CACHE" ]; then
  AGE=$(( $(date +%s) - $(stat -f%m "$CACHE" 2>/dev/null || stat -c%Y "$CACHE" 2>/dev/null || echo 0) ))
  if [ "$AGE" -lt "$CACHE_AGE" ]; then
    CACHED=$(cat "$CACHE")
    [ -n "$CACHED" ] && printf "%s" "$CACHED"
    exit 0
  fi
fi

get_next_meeting_icalbuddy() {
  command -v icalBuddy >/dev/null 2>&1 || return 1
  NOW_EPOCH=$(date +%s)
  LOOKAHEAD_EPOCH=$(( NOW_EPOCH + LOOKAHEAD_MINUTES * 60 ))
  END_DATE=$(date -r "$LOOKAHEAD_EPOCH" "+%Y-%m-%d %H:%M" 2>/dev/null) || return 1

  RESULT=$(icalBuddy \
    -f \
    -nc \
    -npn \
    -iep "title,datetime" \
    -df "" \
    -tf "%H:%M" \
    eventsFrom:"now" to:"$END_DATE" 2>/dev/null | head -4) || return 1

  echo "$RESULT"
}

get_next_meeting_osascript() {
  NOW_EPOCH=$(date +%s)
  LOOKAHEAD_EPOCH=$(( NOW_EPOCH + LOOKAHEAD_MINUTES * 60 ))

  osascript <<APPLESCRIPT 2>/dev/null
set nowDate to current date
set endDate to nowDate + ($LOOKAHEAD_MINUTES * minutes)
set resultTitle to ""
set resultEpoch to 0

tell application "Calendar"
  repeat with cal in calendars
    set evs to (every event of cal whose start date >= nowDate and start date <= endDate)
    repeat with ev in evs
      set evStart to start date of ev
      set evEpoch to (evStart - (date "Thursday, January 1, 1970 at 00:00:00")) as integer
      if resultEpoch = 0 or evEpoch < resultEpoch then
        set resultEpoch to evEpoch
        set resultTitle to summary of ev
      end if
    end repeat
  end repeat
end tell

if resultEpoch > 0 then
  return resultTitle & "|" & resultEpoch
end if
return ""
APPLESCRIPT
}

parse_icalbuddy_output() {
  local raw="$1"
  [ -z "$raw" ] && return 1

  local title=""
  local time_str=""

  while IFS= read -r line; do
    line="${line#"${line%%[! ]*}"}"  # trim leading spaces
    if [ -z "$title" ] && [ -n "$line" ]; then
      title="$line"
    elif echo "$line" | grep -qE "^[0-9]{2}:[0-9]{2}"; then
      time_str=$(echo "$line" | grep -oE "^[0-9]{2}:[0-9]{2}")
      break
    fi
  done <<< "$raw"

  [ -z "$title" ] || [ -z "$time_str" ] && return 1

  local NOW_EPOCH today_date
  NOW_EPOCH=$(date +%s)
  today_date=$(date "+%Y-%m-%d")
  local event_epoch
  event_epoch=$(date -jf "%Y-%m-%d %H:%M" "$today_date $time_str" "+%s" 2>/dev/null) || return 1

  [ "$event_epoch" -le "$NOW_EPOCH" ] && return 1

  echo "${title}|${event_epoch}"
}

format_output() {
  local title="$1"
  local event_epoch="$2"
  local NOW_EPOCH
  NOW_EPOCH=$(date +%s)
  local diff_secs=$(( event_epoch - NOW_EPOCH ))
  local diff_mins=$(( diff_secs / 60 ))

  [ "$diff_mins" -lt 0 ] && return 1
  [ "$diff_mins" -gt "$LOOKAHEAD_MINUTES" ] && return 1

  local short_title="${title:0:25}"
  [ ${#title} -gt 25 ] && short_title="${title:0:22}..."

  local color
  if [ "$diff_mins" -gt 30 ]; then
    color="\033[32m"  # green
  elif [ "$diff_mins" -gt 10 ]; then
    color="\033[33m"  # yellow
  else
    color="\033[31m"  # red
  fi

  printf "%bMtg in %dm: %s\033[0m" "$color" "$diff_mins" "$short_title"
}

MEETING_DATA=""

# Try icalBuddy first
if command -v icalBuddy >/dev/null 2>&1; then
  RAW=$(get_next_meeting_icalbuddy || true)
  if [ -n "$RAW" ]; then
    MEETING_DATA=$(parse_icalbuddy_output "$RAW" || true)
  fi
fi

# Fallback to osascript
if [ -z "$MEETING_DATA" ]; then
  MEETING_DATA=$(get_next_meeting_osascript || true)
fi

if [ -z "$MEETING_DATA" ]; then
  echo -n "" > "$CACHE"
  exit 0
fi

TITLE=$(echo "$MEETING_DATA" | cut -d'|' -f1)
EPOCH=$(echo "$MEETING_DATA" | cut -d'|' -f2)

OUTPUT=$(format_output "$TITLE" "$EPOCH" || true)

echo -n "$OUTPUT" > "$CACHE"
[ -n "$OUTPUT" ] && printf "%s" "$OUTPUT"
