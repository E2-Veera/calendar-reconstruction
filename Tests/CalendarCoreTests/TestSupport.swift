import CalendarCore
import Foundation
import XCTest

/// Fixed Gregorian calendar (UTC, Sunday-first, en_US) so results don't depend on the machine.
func makeCalendar(firstWeekday: Int = 1, timeZone: String = "UTC") -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZone)!
    calendar.locale = Locale(identifier: "en_US")
    calendar.firstWeekday = firstWeekday
    return calendar
}

func date(_ text: String, _ calendar: Calendar = makeCalendar()) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = text.count > 10 ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
    return formatter.date(from: text)!
}

func temporaryStoreURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("CalendarReconstructionTests-\(UUID().uuidString)")
        .appendingPathComponent("store.json")
}

/// Store + controller pinned to `now`, empty unless `seed` is true.
func makeController(now: String = "2026-10-20 10:15", seed: Bool = false, mode: CalendarViewMode = .month,
                    fileURL: URL? = nil) -> CalendarController {
    let calendar = makeCalendar()
    let nowDate = date(now, calendar)
    let store = EventStore(fileURL: fileURL, seedSampleData: seed, calendar: calendar, now: nowDate)
    return CalendarController(store: store, math: CalendarMath(calendar: calendar), mode: mode, now: { nowDate })
}
