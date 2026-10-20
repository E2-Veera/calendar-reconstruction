import Foundation

/// Date arithmetic for the calendar views. All functions honour the supplied `Calendar`
/// (first weekday, time zone, locale), so tests can pin them.
public struct CalendarMath: Sendable {
    public var calendar: Calendar

    public init(calendar: Calendar = .autoupdatingCurrent) {
        self.calendar = calendar
    }

    public func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    public func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }

    public func isSameDay(_ a: Date, _ b: Date) -> Bool { calendar.isDate(a, inSameDayAs: b) }

    public func dayInterval(_ date: Date) -> DateInterval {
        calendar.dateInterval(of: .day, for: date)!
    }

    public func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)!.start
    }

    public func startOfMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)!.start
    }

    /// The seven days of the week containing `date`, starting at the calendar's first weekday.
    public func weekDays(containing date: Date) -> [Date] {
        let start = startOfWeek(date)
        return (0..<7).map { addingDays($0, to: start) }
    }

    /// Whole weeks covering the month of `date` (4–6 rows). Leading/trailing days belong to
    /// the neighbouring months, as in Calendar.app's month view.
    public func monthGrid(for date: Date) -> [[Date]] {
        let month = calendar.dateInterval(of: .month, for: date)!
        var weekStart = startOfWeek(month.start)
        var rows: [[Date]] = []
        while weekStart < month.end {
            rows.append((0..<7).map { addingDays($0, to: weekStart) })
            weekStart = addingDays(7, to: weekStart)
        }
        return rows
    }

    public func numberOfDays(inMonthOf date: Date) -> Int {
        calendar.range(of: .day, in: .month, for: date)!.count
    }

    public static func isLeapYear(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    public func isInSameMonth(_ a: Date, as b: Date) -> Bool {
        calendar.isDate(a, equalTo: b, toGranularity: .month)
    }

    public func isWeekend(_ date: Date) -> Bool { calendar.isDateInWeekend(date) }

    /// Previous/next navigation (⌘← / ⌘→ in Calendar.app). Month and year steps clamp the
    /// day of month (31 Jan + 1 month = 28/29 Feb), which is Foundation's behaviour.
    public func step(_ date: Date, mode: CalendarViewMode, by count: Int) -> Date {
        switch mode {
        case .day: calendar.date(byAdding: .day, value: count, to: date)!
        case .week: calendar.date(byAdding: .day, value: 7 * count, to: date)!
        case .month: calendar.date(byAdding: .month, value: count, to: date)!
        case .year: calendar.date(byAdding: .year, value: count, to: date)!
        }
    }

    /// The span of time a view displays (month view includes its leading/trailing days).
    public func visibleInterval(for mode: CalendarViewMode, containing date: Date) -> DateInterval {
        switch mode {
        case .day:
            return dayInterval(date)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date)!
        case .month:
            let grid = monthGrid(for: date)
            return DateInterval(start: grid.first!.first!, end: addingDays(1, to: grid.last!.last!))
        case .year:
            return calendar.dateInterval(of: .year, for: date)!
        }
    }

    /// Short weekday names ordered from the calendar's first weekday.
    public func orderedWeekdaySymbols(short: Bool = true) -> [String] {
        let symbols = short ? calendar.shortWeekdaySymbols : calendar.weekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    public func formatted(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    /// Header title split into an emphasised and a regular part, like Calendar.app's
    /// "**October** 2026" header.
    public func headerTitle(for mode: CalendarViewMode, date: Date) -> (bold: String, regular: String) {
        let year = formatted(date, template: "y")
        switch mode {
        case .day:
            return (formatted(date, template: "dMMMM"), year)
        case .week:
            let days = weekDays(containing: date)
            let first = days.first!, last = days.last!
            if isInSameMonth(first, as: last) {
                return (formatted(first, template: "MMMM"), formatted(first, template: "y"))
            }
            let lastYear = formatted(last, template: "y")
            if formatted(first, template: "y") != lastYear {
                return ("\(formatted(first, template: "MMM y")) – \(formatted(last, template: "MMM"))", lastYear)
            }
            return ("\(formatted(first, template: "MMM")) – \(formatted(last, template: "MMM"))", lastYear)
        case .month:
            return (formatted(date, template: "MMMM"), year)
        case .year:
            return (year, "")
        }
    }

    public func timeString(_ date: Date) -> String { formatted(date, template: "jmm") }
}
