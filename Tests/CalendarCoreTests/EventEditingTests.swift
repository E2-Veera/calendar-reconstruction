import CalendarCore
import XCTest

/// Test areas 3 and 4: creating, editing and deleting events; all-day events.
final class EventEditingTests: XCTestCase {
    func testCreateEditDeleteThroughController() throws {
        let controller = makeController()
        controller.selectDay(date("2026-10-22"))
        controller.beginNewEvent()
        var draft = try XCTUnwrap(controller.draft)
        XCTAssertTrue(draft.isNew)
        XCTAssertEqual(draft.title, "New Event")
        XCTAssertEqual(draft.start, date("2026-10-22 09:00"))  // not today → 09:00
        XCTAssertEqual(draft.end, date("2026-10-22 10:00"))

        draft.title = "Architecture Review"
        draft.location = "Room 7"
        draft.notes = "Bring the REA report"
        controller.draft = draft
        XCTAssertTrue(controller.commitDraft())
        XCTAssertNil(controller.draft)
        let created = try XCTUnwrap(controller.selectedEvent)
        XCTAssertEqual(created.title, "Architecture Review")
        XCTAssertEqual(controller.events(on: date("2026-10-22")).map(\.title), ["Architecture Review"])

        controller.beginEditing()
        controller.draft?.title = "Architecture Review (moved)"
        controller.draft?.setStart(date("2026-10-23 15:30"))
        XCTAssertTrue(controller.commitDraft())
        let edited = try XCTUnwrap(controller.store.event(id: created.id))
        XCTAssertEqual(edited.title, "Architecture Review (moved)")
        XCTAssertEqual(edited.startDate, date("2026-10-23 15:30"))
        XCTAssertEqual(edited.endDate, date("2026-10-23 16:30"), "moving the start keeps the duration")
        XCTAssertEqual(edited.location, "Room 7")
        XCTAssertTrue(controller.events(on: date("2026-10-22")).isEmpty)

        controller.deleteSelectedEvent()
        XCTAssertNil(controller.store.event(id: created.id))
        XCTAssertNil(controller.selectedEventID)
    }

    func testNewEventOnTodayStartsAtNextHour() {
        let controller = makeController(now: "2026-10-20 10:15")
        controller.beginNewEvent()
        XCTAssertEqual(controller.draft?.start, date("2026-10-20 11:00"))
    }

    func testCancelDiscardsDraft() {
        let controller = makeController()
        controller.beginNewEvent()
        controller.cancelDraft()
        XCTAssertNil(controller.draft)
        XCTAssertTrue(controller.store.events.isEmpty)
    }

    func testEndBeforeStartIsRejected() {
        let controller = makeController()
        controller.beginNewEvent(start: date("2026-10-20 14:00"))
        controller.draft?.setEnd(date("2026-10-20 13:00"))
        XCTAssertEqual(controller.draft?.validationError, .endBeforeStart)
        XCTAssertFalse(controller.commitDraft())
        XCTAssertNotNil(controller.draftError)
        XCTAssertTrue(controller.store.events.isEmpty)
        XCTAssertThrowsError(try controller.store.addEvent(CalendarEvent(
            calendarID: controller.defaultCalendarID, title: "x",
            startDate: date("2026-10-20 14:00"), endDate: date("2026-10-20 13:00"))))
    }

    func testDoubleClickedSlotCreatesEventAtThatTime() {
        let controller = makeController()
        controller.beginNewEvent(start: date("2026-10-21 15:45"))
        XCTAssertTrue(controller.commitDraft())
        XCTAssertEqual(controller.selectedEvent?.startDate, date("2026-10-21 15:45"))
        XCTAssertEqual(controller.selectedEvent?.endDate, date("2026-10-21 16:45"))
    }

    // MARK: All-day

    func testAllDayEventUsesExclusiveEndButInclusiveForm() throws {
        let controller = makeController()
        controller.beginNewEvent(start: date("2026-10-24 13:00"), allDay: true)
        let draft = try XCTUnwrap(controller.draft)
        XCTAssertTrue(draft.isAllDay)
        XCTAssertEqual(draft.start, date("2026-10-24"))
        XCTAssertEqual(draft.end, date("2026-10-24"), "form shows a one-day event as starting and ending the same day")
        XCTAssertTrue(controller.commitDraft())
        let event = try XCTUnwrap(controller.selectedEvent)
        XCTAssertEqual(event.startDate, date("2026-10-24"))
        XCTAssertEqual(event.endDate, date("2026-10-25"))
        XCTAssertEqual(controller.events(on: date("2026-10-24")).count, 1)
        XCTAssertTrue(controller.events(on: date("2026-10-25")).isEmpty, "exclusive end does not leak into next day")
        XCTAssertTrue(controller.events(on: date("2026-10-23")).isEmpty)
    }

    func testMultiDayAllDayEventCoversEveryDay() throws {
        let controller = makeController()
        controller.beginNewEvent(start: date("2026-10-30"), allDay: true)
        controller.draft?.setEnd(date("2026-11-02"))  // inclusive last day, crosses month boundary
        XCTAssertTrue(controller.commitDraft())
        let event = try XCTUnwrap(controller.selectedEvent)
        XCTAssertEqual(event.endDate, date("2026-11-03"))
        for day in ["2026-10-30", "2026-10-31", "2026-11-01", "2026-11-02"] {
            XCTAssertEqual(controller.events(on: date(day)).map(\.id), [event.id], day)
        }
        XCTAssertTrue(controller.events(on: date("2026-11-03")).isEmpty)

        controller.beginEditing()
        XCTAssertEqual(controller.draft?.end, date("2026-11-02"), "editing shows the inclusive last day again")
    }

    func testTogglingAllDay() throws {
        let controller = makeController()
        controller.beginNewEvent(start: date("2026-10-21 15:00"))
        controller.draft?.setAllDay(true, calendar: controller.calendar)
        XCTAssertEqual(controller.draft?.start, date("2026-10-21"))
        XCTAssertEqual(controller.draft?.end, date("2026-10-21"))
        controller.draft?.setAllDay(false, calendar: controller.calendar)
        XCTAssertEqual(controller.draft?.start, date("2026-10-21 09:00"))
        XCTAssertEqual(controller.draft?.end, date("2026-10-21 10:00"))
    }

    func testAllDayEventsSortFirst() throws {
        let controller = makeController()
        let id = controller.defaultCalendarID
        try controller.store.addEvent(CalendarEvent(calendarID: id, title: "Early", startDate: date("2026-10-21 07:00"),
                                                    endDate: date("2026-10-21 08:00")))
        try controller.store.addEvent(CalendarEvent(calendarID: id, title: "Holiday", startDate: date("2026-10-21"),
                                                    endDate: date("2026-10-22"), isAllDay: true))
        XCTAssertEqual(controller.events(on: date("2026-10-21")).map(\.title), ["Holiday", "Early"])
    }

    func testHiddenCalendarEventsAreNotShown() throws {
        let controller = makeController()
        let work = controller.store.addCalendar(name: "Work", colorHex: "#FF2968")
        try controller.store.addEvent(CalendarEvent(calendarID: work.id, title: "Hidden", startDate: date("2026-10-21 07:00"),
                                                    endDate: date("2026-10-21 08:00")))
        XCTAssertEqual(controller.events(on: date("2026-10-21")).count, 1)
        controller.store.setCalendarVisible(id: work.id, false)
        XCTAssertTrue(controller.events(on: date("2026-10-21")).isEmpty)
    }

    func testDeletingCalendarDeletesItsEvents() throws {
        let controller = makeController()
        let work = controller.store.addCalendar(name: "Work", colorHex: "#FF2968")
        try controller.store.addEvent(CalendarEvent(calendarID: work.id, title: "W", startDate: date("2026-10-21 07:00"),
                                                    endDate: date("2026-10-21 08:00")))
        try controller.store.deleteCalendar(id: work.id)
        XCTAssertTrue(controller.store.events.isEmpty)
        XCTAssertThrowsError(try controller.store.deleteCalendar(id: controller.store.calendars[0].id))
    }
}
