# Reverse-engineering report: macOS Calendar.app → Calendar Reconstruction

Date: 2026-10-20 · Host: macOS 26.5.2 (25F84), arm64 · Tool: REA (`rea-agents`) 6.5.0

## 1. Target

| Fact | Value | Source |
|---|---|---|
| Bundle | `/System/Applications/Calendar.app` | filesystem |
| Identifier / version | `com.apple.iCal`, 16.0 (3036.4.14) | `rea inspect-plist` |
| Principal class | `CALApplication` | `rea inspect-plist` |
| Executable | Mach-O universal (x86_64 + arm64e), SHA-256 `0185c8e8…7f853` | `rea inspect-macho`, `shasum` |
| Signing | Apple "Software Signing", app sandbox, entitlement `com.apple.security.personal-information.calendars` + private `com.apple.private.calendar*` | `rea inspect-signature` |
| UI technology | AppKit (`AppKit.framework`) + Swift runtime; calendar UI in private `CalendarUI`, `CalendarUIKit`, `CalendarDraw`; data via `EventKit`, `CalendarDatabase`, `CalDAV`, `iCalendar` frameworks | `rea inspect-macho` (87 linked dylibs) |
| Interface Builder | 36 compiled nibs decoded: 5,811 graph nodes, 2,537 edges | `rea decode-interface-builder` |

All raw output is in `evidence/rea/` and can be regenerated with `scripts/collect_evidence.sh`.

## 2. What REA could and could not do on this Mac

| Capability | Status | Detail |
|---|---|---|
| Plist / Mach-O / code signature / Interface Builder decoding | ✅ Used | Provider-free REA commands |
| Asset catalog (`Assets.car`) | ❌ REA rejected it (`unsupported binary format`) | Fallback: Apple's `xcrun assetutil --info` |
| Disassembly / decompilation | ❌ Not available | `rea doctor`: no Hopper, Ghidra or IDA installed. No code-level findings are claimed. |
| Live UI tree (`observe-native-ui`) and window screenshots | ❌ Blocked | `accessibility-denied` and `screen-recording-denied` for Terminal, still denied after a Terminal restart. Run `scripts/capture_live_ui.sh` once they are granted. |
| User's calendar database | Deliberately not touched | Private data, TCC-protected |
| Project in `~/Documents` | Moved | Terminal lost `~/Documents` access mid-session, so the project now lives in `~/CalendarReconstruction` |

Apple's source code was **not** recovered, and was never a goal. Everything below is resource-level
or observable evidence, re-implemented in independent code.

## 3. Evidence → behavior (observed vs. assumed)

**O** = observed directly in Calendar.app's resources by REA or Apple tools. **A** = assumption or
general knowledge, not recovered in this session. **I** = inference from observed strings without
seeing the runtime behavior.

### 3.1 Views and navigation. Source: `MainMenu.nib` decoded by REA ([mainmenu-resolved.md](../evidence/rea/mainmenu-resolved.md))

| Behavior | Evidence | Kind | Reconstruction |
|---|---|---|---|
| Day / Week / Month / Year views on ⌘1 / ⌘2 / ⌘3 / ⌘4 | Menu items "By Day/Week/Month/Year" → `switchToDayView:` etc., key equivalents 1–4 + ⌘ | O | Same shortcuts, same order |
| Previous / Next on ⌘← / ⌘→ | "Previous"/"Next", key ``/`` (arrow keys) + ⌘ | O | Same |
| Go to Today ⌘T; Go to Date… ⇧⌘T | `goToCurrentDay:`, `goToDay:` | O | Same |
| View names, segment titles | Localizable: "Day", "Week", "Month", "Year", "Today" | O | Same labels |
| Week header for a week spanning two months | Localizable `%@, Week %@` exists; exact layout not seen | I | "Sep – Oct 2026" |
| Day view side panel (mini month + event details) | Bundle contains `dayview.aplmodel`, `selectedevents.aplmodel` (content not decoded) | A | Implemented |
| Year view busy-day shading | Named colors `HeatmapIntensity1-3_Background/_Text` | O (colors), I (usage) | 3-level heat map |
| Calendar remembers the last view | User defaults key `last calendar view description = Monthly` | O | Saved in UserDefaults |

### 3.2 Events. Sources: `iCal.sdef` ([data-model.md](../evidence/rea/data-model.md)), Localizable ([ui-strings.md](../evidence/rea/ui-strings.md))

| Behavior | Evidence | Kind | Reconstruction |
|---|---|---|---|
| Event fields: summary, location, description (notes), start date, end date, allday event | sdef `event` class | O | `CalendarEvent` with the same fields |
| Calendar fields: name, color, description | sdef `calendar` class | O | `CalendarInfo` (name, color, visibility) |
| New event ⌘N, Edit Event ⌘E, Delete, Duplicate ⌘D | `newEventCommand:`, `editEvent:`, `delete:`, `duplicate:` | O | ⌘N, ⌘E, Delete implemented. Duplicate **not** implemented |
| Default new title "New Event"; nameless shown as "Untitled" | Localizable "New Event", "Untitled" | O (strings), I (usage) | Same |
| All-day label "all-day" | Localizable "all-day", "All-Day" | O | "all-day" row label and toggle |
| All-day = exclusive end date | EventKit is linked; this is standard EventKit semantics | A | Stored exclusive, shown inclusive in the form |
| End before start is invalid | String "The repeat setting … is shorter than its duration" (similar validation family) | I | Rejected with a message |
| Editing UI is an inspector popover | Menu "Show Inspector" ⌥⌘I, "Get Info" ⌘I | O (existence) | **Approximate**: modal sheet |

### 3.3 Search. Source: Localizable

| Behavior | Evidence | Kind | Reconstruction |
|---|---|---|---|
| Find ⌘F | `find:` | O | Focuses the toolbar search field (macOS 15+) |
| Search matches title, location, notes (also invitees, organizer) | "Title contains “%@”", "Location contains “%@”", "Notes contain “%@”", "Invitees contain…", "Organizer contains…", "Event contains…" | O (strings) | Title/location/notes, shown with the same wording. No invitees |
| Results list | "Search Results", "Show/Hide Search Results", "No Events" | O | Side panel; clicking a result jumps to the event |
| Case/diacritic-insensitive, all terms must match, chronological order | — | A | Implemented as stated |

### 3.4 Calendars and colors. Source: `Assets.car` via `assetutil` ([named-colors.md](../evidence/rea/named-colors.md))

| Behavior | Evidence | Kind | Reconstruction |
|---|---|---|---|
| Accent (today marker, now line) `#FF3B30` light / `#FF453A` dark | `CalendarAccentColor` | O | Same values |
| Text on today marker: white (light) / black (dark) | `ActiveDateLabelColor` | O | Same |
| Weekend column background 0.976 gray | `WeekendBackgroundColor` | O | Same |
| Hour gridlines differ for weekday / weekend / today × work / off hours | `CanvasGridline{Weekday,Weekend,Today}{Work,Off}HoursColor` | O | Same 6 colors. Work hours 08–18 is **A** |
| All-day divider, month header divider | `AllDayDividerColor`, `MonthViewTopDividerColor` | O | Same |
| Calendar list toggled from View menu | "Show/Hide Calendar List" (`calendarsListButtonToggle:`), ⌘0 Calendar window | O | Sidebar (NavigationSplitView toggle) |
| Per-calendar color palette (red, orange, …) | Not in Assets.car (likely in private frameworks, not analysed) | A | Standard Apple palette hex values |
| New Calendar ⌥⌘N | `newCalendar:` | O | Same shortcut |

No images, icons or other proprietary assets were copied. Only numeric color values and the
wording of standard UI strings were reused.

## 4. Reconstruction decisions

1. **Reuse first.** Searched for maintained open-source macOS calendar apps. CalBridge (menu bar,
   month/week only), CalendarX and CornerCal (menu-bar widgets), KVKCalendar and CalendarKit
   (UIKit/Catalyst libraries) do not provide a windowed Day/Week/Month app with editing. So the app
   was built from scratch.
2. **Swift + SwiftUI, macOS 14+.** Smallest native option. Logic lives in a UI-free `CalendarCore`
   module so it can be unit tested.
3. **No EventKit.** Using it would require calendar permission and would modify the presenter's real
   calendars during a demo. Instead the app uses local JSON persistence (atomic write after every
   change, corrupt-file recovery) and sample data generated relative to today.
4. **Layout.** Overlapping timed events share column width. All-day and multi-day events are lane
   bars that span days in both week and month views. Month cells collapse overflow into "N more…"
   (Calendar.app string "More events hidden").
5. **Headless CLI and offscreen renderer** in the same binary, so persistence across real process
   restarts and visual output can be tested without UI-automation permissions.

## 5. Match assessment

| Area | Status |
|---|---|
| View set, shortcuts, navigation semantics | **Match** (from MainMenu.nib) |
| Event data model (title, start, end, all-day, location, notes, calendar) | **Match** (from sdef) |
| Calendar list with colored checkboxes, show/hide | **Match** in function; visual details approximate |
| Search fields and result wording | **Match** for title/location/notes; invitees/organizer **incomplete** |
| Color tokens (accent, weekend, gridlines, heat map) | **Match** (exact values) |
| Month / week / day / year layout and typography | **Approximate**: based on general knowledge of Calendar.app, not on side-by-side screenshots (blocked) |
| Event editing UI | **Approximate**: sheet instead of popover inspector |
| Drag to move or resize events, Duplicate, recurrence, alerts, invitees, time zones, import/export (.ics), printing, iCloud/CalDAV accounts, Reminders | **Not implemented** |
| Live UI-tree and screenshot comparison with the original | **Incomplete**: blocked by permissions. `scripts/capture_live_ui.sh` is ready to run |

## 6. Validation

See [test-results/summary.md](test-results/summary.md). All results were actually executed on this
Mac: 40 unit tests and 7 end-to-end checks. GUI interaction (clicking, typing) was not automated
because Accessibility permission is denied, so those flows are covered at the controller level and
by the manual demo script.
