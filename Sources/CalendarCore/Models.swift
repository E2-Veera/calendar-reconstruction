import Foundation

/// A user calendar ("Home", "Work", ...). Mirrors the `calendar` class of Calendar.app's
/// scripting dictionary (name, color, description) — see evidence/rea/data-model.md.
public struct CalendarInfo: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// sRGB hex string, e.g. "#1BADF8".
    public var colorHex: String
    /// Checkbox state in the calendar list; hidden calendars' events are not drawn.
    public var isVisible: Bool

    public init(id: UUID = UUID(), name: String, colorHex: String, isVisible: Bool = true) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.isVisible = isVisible
    }
}

/// An event. Field set mirrors the `event` class of Calendar.app's scripting dictionary:
/// summary (title), location, description (notes), start date, end date, allday event.
///
/// All-day events follow EventKit semantics: `startDate` is the start of the first day and
/// `endDate` is the start of the day *after* the last day (exclusive end).
public struct CalendarEvent: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var calendarID: UUID
    public var title: String
    public var startDate: Date
    public var endDate: Date
    public var isAllDay: Bool
    public var location: String
    public var notes: String

    public init(id: UUID = UUID(), calendarID: UUID, title: String, startDate: Date, endDate: Date,
                isAllDay: Bool = false, location: String = "", notes: String = "") {
        self.id = id
        self.calendarID = calendarID
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
    }

    /// Title shown in the UI. Calendar.app ships the string "Untitled" for nameless items.
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    /// True when the event occupies any part of `interval`. Zero-length events count when
    /// their start lies inside the interval.
    public func overlaps(_ interval: DateInterval) -> Bool {
        if startDate == endDate {
            return startDate >= interval.start && startDate < interval.end
        }
        return startDate < interval.end && endDate > interval.start
    }

    /// Spans more than one calendar day (drawn as a bar in month/week all-day areas).
    public func isMultiDay(calendar: Calendar) -> Bool {
        let firstDay = calendar.startOfDay(for: startDate)
        let lastInstant = endDate > startDate ? endDate.addingTimeInterval(-1) : endDate
        return calendar.startOfDay(for: lastInstant) > firstDay
    }
}

public enum CalendarViewMode: String, CaseIterable, Codable, Sendable, Identifiable {
    case day, week, month, year
    public var id: String { rawValue }
    /// Segment labels, from Calendar.app's Localizable strings ("Day", "Week", "Month", "Year").
    public var label: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }
}

/// Default palette offered when creating calendars. These are the standard Apple calendar
/// colours as commonly documented; they were NOT recovered from Calendar.app's asset catalog
/// (which contains no calendar colours) — see the reverse-engineering report.
public enum CalendarPalette {
    public static let colors: [(name: String, hex: String)] = [
        ("Red", "#FF2968"), ("Orange", "#FF9500"), ("Yellow", "#FFCC00"), ("Green", "#63DA38"),
        ("Blue", "#1BADF8"), ("Purple", "#CC73E1"), ("Brown", "#A2845E"),
    ]
}
