import Foundation

/// Editable copy of an event backing the event form. For all-day events the form shows an
/// *inclusive* end day (a one-day event starts and ends on the same date, as in Calendar.app),
/// while the stored event uses an exclusive end.
public struct EventDraft: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var isNew: Bool
    public var calendarID: UUID
    public var title: String
    public var location: String
    public var notes: String
    public private(set) var isAllDay: Bool
    public private(set) var start: Date
    public private(set) var end: Date

    public init(event: CalendarEvent, isNew: Bool, calendar: Calendar) {
        id = event.id
        self.isNew = isNew
        calendarID = event.calendarID
        title = event.title
        location = event.location
        notes = event.notes
        isAllDay = event.isAllDay
        start = event.startDate
        if event.isAllDay {
            let lastInstant = event.endDate > event.startDate ? event.endDate.addingTimeInterval(-1) : event.startDate
            end = calendar.startOfDay(for: lastInstant)
        } else {
            end = event.endDate
        }
    }

    /// Changing the start keeps the duration, as Calendar.app's inspector does.
    public mutating func setStart(_ newStart: Date) {
        let duration = end.timeIntervalSince(start)
        start = newStart
        end = newStart.addingTimeInterval(max(0, duration))
    }

    public mutating func setEnd(_ newEnd: Date) { end = newEnd }

    /// Toggling all-day on keeps the dates; toggling it off schedules 09:00–10:00 on the start day.
    public mutating func setAllDay(_ on: Bool, calendar: Calendar) {
        guard on != isAllDay else { return }
        isAllDay = on
        if on {
            start = calendar.startOfDay(for: start)
            end = max(start, calendar.startOfDay(for: end))
        } else {
            start = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: start)!
            end = start.addingTimeInterval(3600)
        }
    }

    public var validationError: StoreError? {
        end < start ? .endBeforeStart : nil
    }

    public func makeEvent(calendar: Calendar) throws -> CalendarEvent {
        if let validationError { throw validationError }
        let startDate = isAllDay ? calendar.startOfDay(for: start) : start
        let endDate = isAllDay
            ? calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: end))!
            : end
        return CalendarEvent(id: id, calendarID: calendarID, title: title, startDate: startDate, endDate: endDate,
                             isAllDay: isAllDay, location: location, notes: notes)
    }
}
