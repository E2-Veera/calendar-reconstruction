# Demo script (about 10 minutes)

## Before the meeting
```bash
cd ~/CalendarReconstruction
./scripts/build_app.sh
"build/Calendar Reconstruction.app/Contents/MacOS/CalendarReconstruction" --reset   # fresh demo data, opens the window
```
Have `docs/REVERSE_ENGINEERING_REPORT.md` and `evidence/rea/mainmenu-resolved.md` open in a second window.

## 1. The story (1 min)
"We pointed REA at `/System/Applications/Calendar.app`. Without source code, it decoded the
Info.plist, the code signature, the Mach-O load commands and all 36 Interface Builder nibs. From
those we recovered the menu structure, shortcuts and action selectors, the event data model, UI
strings and the exact theme colors. We then rebuilt the core features as an independent SwiftUI app."

Show `evidence/rea/mainmenu-resolved.md`: "By Day ⌘1 → `switchToDayView:`" and similar rows.

## 2. Views and navigation (2 min)
1. The app opens in **Month** view on today (red marker, using `CalendarAccentColor`).
2. Press **⌘2** (Week), **⌘1** (Day), **⌘4** (Year), **⌘3** (Month). These are the shortcuts
   recovered from MainMenu.nib.
3. Press **⌘→** twice to go forward two months, then **⌘T** to return to today.
4. In Year view, point out the busy-day heat map, which uses Calendar.app's `HeatmapIntensity` colors.
   Double-click a day to open it in Day view.
5. **⇧⌘T** → Go to Date… → choose 29 Feb 2028 → it's a leap day.

## 3. Create, edit, delete (3 min)
1. Week view: point out the overlapping "Product Sync" and "Customer Call" side by side, and the
   red current-time line.
2. **Double-click** an empty slot on Thursday at 15:00 → the form opens with "New Event" 15:00–16:00.
   Title "Team Demo", location "Room 7", notes "Show REA evidence" → **Add**.
3. Click the event to select it, then press **⌘E**. Change the start to 16:00 (the end moves to
   17:00 automatically) → **Save**.
4. Toggle **all-day** on a new event (⌘N), set it to end two days later → it appears as a bar
   spanning days in the all-day strip and in Month view.
5. Select "Team Demo" and press **Delete**. It's gone.

## 4. Calendars and search (2 min)
1. Uncheck **Work** in the sidebar: all red events disappear. Re-check it.
2. Sidebar **+** (or ⌥⌘N) → new calendar "Demo", color orange.
3. Type `review` in the search field (⌘F). The results show "Title contains “review”", wording
   recovered from Calendar.app's strings. Click a result to jump to the event.

## 5. Persistence (1 min)
Quit (⌘Q) and reopen: everything you changed is still there. Optionally, in a terminal:
```bash
"build/Calendar Reconstruction.app/Contents/MacOS/CalendarReconstruction" --search demo
```

## 6. Honest scorecard (1 min)
Open the report, section 5:
- **Recovered with REA:** shortcuts, view set, data model, search tokens, colors.
- **Independently implemented:** all code, layout algorithms, JSON storage.
- **Approximate:** popover inspector vs. sheet, pixel layout.
- **Missing:** drag to move, recurrence, invitees, accounts, .ics import/export.
- **Blocked:** live UI-tree and screenshot comparison (needs Accessibility + Screen Recording;
  `scripts/capture_live_ui.sh` is ready).

Finish with `./scripts/run_tests.sh` → 40 unit tests and 7 end-to-end checks pass.
