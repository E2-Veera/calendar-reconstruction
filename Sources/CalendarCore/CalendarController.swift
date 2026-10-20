import Foundation
import Observation

/// UI state and commands of the main window, independent of SwiftUI so it can be unit tested.
/// Command names follow the selectors recovered from Calendar.app's MainMenu.nib
/// (goToCurrentDay:, switchToDayView:, newEventCommand:, editEvent:, find:, ...).
@Observable
public final class CalendarController {
    public let store: EventStore
    public var math: CalendarMath
    public var mode: CalendarViewMode
    /// Anchor date of the visible period.
    public private(set) var displayedDate: Date
    public var selectedDay: Date
    public var selectedEventID: UUID?
    public var searchText: String = ""
    public var draft: EventDraft?
    public var draftError: String?
    private let now: () -> Date

    public init(store: EventStore, math: CalendarMath = CalendarMath(), mode: CalendarViewMode = .month,
                now: @escaping () -> Date = Date.init) {
        self.store = store
        self.math = math
        self.mode = mode
        self.now = now
        let today = math.startOfDay(now())
        displayedDate = today
        selectedDay = today
    }

    public var today: Date { math.startOfDay(now()) }
    public var currentTime: Date { now() }
    public var calendar: Calendar { math.calendar }

    // MARK: Navigation

    /// "Go to Today" (⌘T, goToCurrentDay:).
    public func goToToday() { go(to: today) }

    /// "Next" (⌘→).
    public func goNext() { go(to: math.step(displayedDate, mode: mode, by: 1)) }

    /// "Previous" (⌘←).
    public func goPrevious() { go(to: math.step(displayedDate, mode: mode, by: -1)) }

    /// "Go to Date…" (⇧⌘T, goToDay:).
    public func go(to date: Date) {
        displayedDate = math.startOfDay(date)
        selectedDay = displayedDate
    }

    /// switchToDayView: / switchToWeekView: / switchToMonthView: / switchToYearView: (⌘1–⌘4).
    /// The selected day is kept so switching views stays on the same date.
    public func setMode(_ newMode: CalendarViewMode) {
        mode = newMode
        displayedDate = selectedDay
    }

    public func selectDay(_ day: Date) { selectedDay = math.startOfDay(day) }

    /// Opens a day in Day view (double-click in Year view).
    public func showDay(_ day: Date) {
        go(to: day)
        mode = .day
    }

    public var visibleInterval: DateInterval { math.visibleInterval(for: mode, containing: displayedDate) }
    public var headerTitle: (bold: String, regular: String) { math.headerTitle(for: mode, date: displayedDate) }
    public var visibleEvents: [CalendarEvent] { store.events(in: visibleInterval) }

    public func events(on day: Date) -> [CalendarEvent] { store.events(in: math.dayInterval(day)) }

    // MARK: Selection

    public var selectedEvent: CalendarEvent? { selectedEventID.flatMap(store.event(id:)) }

    public func selectEvent(_ id: UUID?) {
        selectedEventID = id
        if let event = id.flatMap(store.event(id:)) { selectedDay = math.startOfDay(event.startDate) }
    }

    /// Selecting a search result navigates to the event's date and selects it.
    public func reveal(_ eventID: UUID) {
        guard let event = store.event(id: eventID) else { return }
        go(to: event.startDate)
        selectedEventID = eventID
    }

    // MARK: Search

    public var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }
    public var searchResults: [SearchResult] { store.search(searchText) }

    // MARK: Editing

    /// Default calendar for new events: the first visible calendar.
    public var defaultCalendarID: UUID {
        (store.calendars.first(where: \.isVisible) ?? store.calendars[0]).id
    }

    /// "New Event" (⌘N, newEventCommand:). Without an explicit start: the next whole hour when the
    /// selected day is today, else 09:00 on the selected day. One hour long, titled "New Event".
    public func beginNewEvent(start: Date? = nil, allDay: Bool = false) {
        let startDate: Date
        if let start {
            startDate = start
        } else if math.isSameDay(selectedDay, now()) {
            let hourStart = calendar.dateInterval(of: .hour, for: now())!.end
            startDate = math.isSameDay(hourStart, selectedDay) ? hourStart
                : calendar.date(bySettingHour: 23, minute: 0, second: 0, of: selectedDay)!
        } else {
            startDate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDay)!
        }
        let event: CalendarEvent
        if allDay {
            let day = math.startOfDay(startDate)
            event = CalendarEvent(calendarID: defaultCalendarID, title: "New Event", startDate: day,
                                  endDate: math.addingDays(1, to: day), isAllDay: true)
        } else {
            event = CalendarEvent(calendarID: defaultCalendarID, title: "New Event", startDate: startDate,
                                  endDate: startDate.addingTimeInterval(3600))
        }
        draftError = nil
        draft = EventDraft(event: event, isNew: true, calendar: calendar)
    }

    /// "Edit Event" (⌘E, editEvent:).
    public func beginEditing(_ eventID: UUID? = nil) {
        guard let id = eventID ?? selectedEventID, let event = store.event(id: id) else { return }
        selectedEventID = id
        draftError = nil
        draft = EventDraft(event: event, isNew: false, calendar: calendar)
    }

    @discardableResult
    public func commitDraft() -> Bool {
        guard let draft else { return false }
        do {
            let event = try draft.makeEvent(calendar: calendar)
            if draft.isNew { try store.addEvent(event) } else { try store.updateEvent(event) }
            selectedEventID = event.id
            selectedDay = math.startOfDay(event.startDate)
            self.draft = nil
            draftError = nil
            return true
        } catch {
            draftError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    public func cancelDraft() {
        draft = nil
        draftError = nil
    }

    public func deleteEvent(_ id: UUID) {
        store.deleteEvent(id: id)
        if selectedEventID == id { selectedEventID = nil }
        if draft?.id == id { draft = nil }
    }

    /// Delete key / Edit ▸ Delete on the selected event.
    public func deleteSelectedEvent() {
        if let id = selectedEventID { deleteEvent(id) }
    }
}
