# Automated test results

- Run at: 2026-10-20 12:22:50 IST
- Host: macOS 26.5.2 (arm64), Apple Swift version 6.2 (swiftlang-6.2.0.19.9 clang-1700.3.19.1)

| Check | Result | Detail |
|---|---|---|
| Unit tests (XCTest) | PASS | Executed 40 tests, with 0 failures (0 unexpected) in 0.048 (0.051) seconds |
| Build .app bundle | PASS | build/Calendar Reconstruction.app |
| Launch application | PASS | pid 18611 alive with 1 main window(s) on screen |
| First launch seeds sample data | PASS | 20 events written to the data file |
| Persist & restore after restart | PASS | timed + all-day leap-day events restored by a new process after a GUI session (OK total=22) |
| Delete persists after restart | PASS | event absent in a fresh process |
| Search (headless) | PASS | 2 result(s) for “review” |
| Offscreen renders of all views | PASS | 6 PNGs in evidence/screenshots/ |

**Total: 8 passed, 0 failed.**

Not automated (blocked): driving the GUI with clicks/keystrokes and capturing real window
screenshots both require Accessibility + Screen Recording permission for the terminal, which
were denied on this Mac. Those flows are covered at the controller level by the unit tests
and must be checked by hand with docs/DEMO_SCRIPT.md.
