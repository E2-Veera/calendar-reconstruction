#!/bin/zsh
# Runs every automated check and writes results to docs/test-results/.
#   1. Unit tests (swift test)                         — navigation, CRUD, all-day, persistence,
#                                                        search, month boundaries, leap years, layout
#   2. Build the .app bundle
#   3. GUI launch test: app starts, shows a window, stays alive, quits
#   4. Restart persistence across real processes (headless add → new process list → GUI session → list)
#   5. Headless search
#   6. Offscreen screenshot renders
# Uses a throwaway data file; never touches your real calendars or the app's default store.
set -u
ROOT="${0:A:h:h}"
cd "$ROOT"
OUT="$ROOT/docs/test-results"
mkdir -p "$OUT"
WORK="$(mktemp -d -t calrecon-tests)"
STORE="$WORK/store.json"
BIN="$ROOT/build/Calendar Reconstruction.app/Contents/MacOS/CalendarReconstruction"
SUMMARY="$OUT/summary.md"
PASS=0; FAIL=0

result() {  # name status detail
  if [[ $2 == PASS ]]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
  echo "| $1 | $2 | $3 |" >> "$SUMMARY"
  echo "[$2] $1 — $3"
}

{
  echo "# Automated test results"
  echo
  echo "- Run at: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "- Host: macOS $(sw_vers -productVersion) ($(uname -m)), $(swift --version 2>/dev/null | head -1)"
  echo
  echo "| Check | Result | Detail |"
  echo "|---|---|---|"
} > "$SUMMARY"

# 1. Unit tests
swift test > "$OUT/unit-tests.log" 2>&1
UNIT_STATUS=$?
EXECUTED=$(grep -E "Executed [0-9]+ tests" "$OUT/unit-tests.log" | tail -1 | sed -E 's/^[[:space:]]+//')
if [[ $UNIT_STATUS -eq 0 ]]; then result "Unit tests (XCTest)" PASS "$EXECUTED"
else result "Unit tests (XCTest)" FAIL "exit $UNIT_STATUS — see unit-tests.log"; fi

# 2. Build
if ./scripts/build_app.sh > "$OUT/build.log" 2>&1; then result "Build .app bundle" PASS "build/Calendar Reconstruction.app"
else result "Build .app bundle" FAIL "see build.log"; echo "Build failed; stopping."; exit 1; fi

window_count() {
  swift "$ROOT/scripts/winlist.swift" "$1" 2>/dev/null | awk '$2 == 0 && $3 > 400' | wc -l | tr -d ' '
}

# 3. GUI launch
"$BIN" --store "$STORE" --reset > "$OUT/gui-launch.log" 2>&1 &
APP_PID=$!
WINDOWS=0
for _ in {1..20}; do
  sleep 0.5
  WINDOWS=$(window_count $APP_PID)
  [[ $WINDOWS -ge 1 ]] && break
done
sleep 1
if kill -0 $APP_PID 2>/dev/null && [[ $WINDOWS -ge 1 ]]; then
  result "Launch application" PASS "pid $APP_PID alive with $WINDOWS main window(s) on screen"
else
  result "Launch application" FAIL "alive=$(kill -0 $APP_PID 2>/dev/null && echo yes || echo no) windows=$WINDOWS"
fi
SEEDED=$(python3 -I -c "import json,sys;print(len(json.load(open(sys.argv[1]))['events']))" "$STORE" 2>/dev/null || echo 0)
if [[ $SEEDED -gt 10 ]]; then result "First launch seeds sample data" PASS "$SEEDED events written to the data file"
else result "First launch seeds sample data" FAIL "events=$SEEDED"; fi
kill -TERM $APP_PID 2>/dev/null; wait $APP_PID 2>/dev/null

# 4. Restart persistence across processes
"$BIN" --store "$STORE" --add-event "Restart Test Event" --start 2028-02-29T10:00 --end 2028-02-29T11:30 \
  --calendar Work --location "Room 42" --notes "persisted across processes" > "$OUT/persistence.log" 2>&1
"$BIN" --store "$STORE" --add-event "Leap Day Holiday" --start 2028-02-29 --all-day --calendar Home >> "$OUT/persistence.log" 2>&1
# a GUI session in between must not lose or duplicate data
"$BIN" --store "$STORE" > /dev/null 2>&1 &
GUI2=$!; sleep 3; kill -TERM $GUI2 2>/dev/null; wait $GUI2 2>/dev/null
"$BIN" --store "$STORE" --list-events > "$WORK/list.json" 2>>"$OUT/persistence.log"
CHECK=$(python3 -I - "$WORK/list.json" <<'PY'
import json, sys
events = json.load(open(sys.argv[1]))
timed = [e for e in events if e["title"] == "Restart Test Event"]
allday = [e for e in events if e["title"] == "Leap Day Holiday"]
ok = (len(timed) == 1 and timed[0]["location"] == "Room 42" and timed[0]["calendar"] == "Work"
      and timed[0]["start"].startswith("2028-02-29T10:00") and not timed[0]["allDay"]
      and len(allday) == 1 and allday[0]["allDay"] and allday[0]["start"].startswith("2028-02-29T00:00")
      and allday[0]["end"].startswith("2028-03-01T00:00"))
print(("OK" if ok else "BAD") + f" total={len(events)}")
PY
)
if [[ $CHECK == OK* ]]; then result "Persist & restore after restart" PASS "timed + all-day leap-day events restored by a new process after a GUI session ($CHECK)"
else result "Persist & restore after restart" FAIL "$CHECK"; fi

"$BIN" --store "$STORE" --delete-event "Restart Test Event" >> "$OUT/persistence.log" 2>&1
if ! "$BIN" --store "$STORE" --list-events | grep -q "Restart Test Event"; then
  result "Delete persists after restart" PASS "event absent in a fresh process"
else result "Delete persists after restart" FAIL "event still listed"; fi

# 5. Search
"$BIN" --store "$STORE" --search review > "$OUT/search.log" 2>&1
if grep -q "Design Review" "$OUT/search.log" && grep -q "Title contains" "$OUT/search.log"; then
  result "Search (headless)" PASS "$(wc -l < "$OUT/search.log" | tr -d ' ') result(s) for “review”"
else result "Search (headless)" FAIL "see search.log"; fi

# 6. Screenshots
if "$BIN" --store "$STORE" --render-screenshots "$ROOT/evidence/screenshots" > "$OUT/screenshots.log" 2>&1; then
  result "Offscreen renders of all views" PASS "$(wc -l < "$OUT/screenshots.log" | tr -d ' ') PNGs in evidence/screenshots/"
else result "Offscreen renders of all views" FAIL "see screenshots.log"; fi

{
  echo
  echo "**Total: $PASS passed, $FAIL failed.**"
  echo
  echo "Not automated (blocked): driving the GUI with clicks/keystrokes and capturing real window"
  echo "screenshots both require Accessibility + Screen Recording permission for the terminal, which"
  echo "were denied on this Mac. Those flows are covered at the controller level by the unit tests"
  echo "and must be checked by hand with docs/DEMO_SCRIPT.md."
} >> "$SUMMARY"

rm -rf "$WORK"
echo "Summary: $SUMMARY ($PASS passed, $FAIL failed)"
[[ $FAIL -eq 0 ]]
