#!/bin/zsh
# Live side-by-side evidence: REA accessibility tree + window screenshot of Apple's Calendar.app
# and of the reconstruction. Read-only observation.
#
# PREREQUISITE (was denied when this POC was built): grant your terminal app
#   System Settings → Privacy & Security → Accessibility        → Terminal ✓
#   System Settings → Privacy & Security → Screen & System Audio Recording → Terminal ✓
# then quit and reopen Terminal.
#
# NOTE: the Calendar.app capture shows YOUR real calendar events. Output stays in evidence/live/.
set -u
ROOT="${0:A:h:h}"
REA="$ROOT/tools/node_modules/.bin/rea"
OUT="$ROOT/evidence/live"
mkdir -p "$OUT"
cd "$ROOT"

main_window() {  # pid → id of the largest on-screen layer-0 window
  swift "$ROOT/scripts/winlist.swift" "$1" | awk '$2 == 0 {print $3*$4, $1}' | sort -rn | head -1 | awk '{print $2}'
}

observe() {  # label app-path pid
  local wid
  wid=$(main_window "$3")
  [[ -z $wid ]] && { echo "$1: no window found"; return 1; }
  "$REA" observe-native-ui "$2" --pid "$3" --window-id "$wid" --max-nodes 1500 --format json > "$OUT/$1-observe.json" 2>&1
  echo "$1: rea observe-native-ui exit=$? → $OUT/$1-observe.json"
  screencapture -o -x -l "$wid" "$OUT/$1-window.png" && echo "$1: screenshot → $OUT/$1-window.png"
}

open -a Calendar
sleep 3
observe original-calendar /System/Applications/Calendar.app "$(pgrep -x Calendar | head -1)"

APP="$ROOT/build/Calendar Reconstruction.app"
[[ -d $APP ]] || ./scripts/build_app.sh
"$APP/Contents/MacOS/CalendarReconstruction" --store "$OUT/demo-store.json" --reset &
PID=$!
sleep 4
observe reconstruction "$APP" "$PID"
kill -TERM "$PID"
