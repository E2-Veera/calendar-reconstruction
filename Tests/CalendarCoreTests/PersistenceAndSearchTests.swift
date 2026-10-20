import CalendarCore
import XCTest

/// Test areas 5 and 6: persistence across restarts; searching.
final class PersistenceTests: XCTestCase {
    func testEventsSurviveRestart() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let first = makeController(seed: true, fileURL: url)
        let seededCount = first.store.events.count
        XCTAssertGreaterThan(seededCount, 10, "first launch is seeded with demo events")
        first.beginNewEvent(start: date("2026-10-21 16:00"))
        first.draft?.title = "Persisted Meeting"
        first.draft?.location = "Café"
        first.draft?.notes = "ünïcödé notes"
        XCTAssertTrue(first.commitDraft())
        let createdID = try XCTUnwrap(first.selectedEventID)
        let hiddenCalendar = first.store.calendars[1].id
        first.store.setCalendarVisible(id: hiddenCalendar, false)

        // "Restart": a brand-new store reading the same file must not re-seed.
        let second = makeController(seed: true, fileURL: url)
        XCTAssertEqual(second.store.events.count, seededCount + 1)
        let restored = try XCTUnwrap(second.store.event(id: createdID))
        XCTAssertEqual(restored.title, "Persisted Meeting")
        XCTAssertEqual(restored.startDate, date("2026-10-21 16:00"))
        XCTAssertEqual(restored.notes, "ünïcödé notes")
        XCTAssertEqual(second.store.calendar(id: hiddenCalendar)?.isVisible, false)

        second.deleteEvent(createdID)
        let third = makeController(seed: true, fileURL: url)
        XCTAssertNil(third.store.event(id: createdID))
        XCTAssertEqual(third.store.events.count, seededCount)
    }

    func testAllDayEventSurvivesRestart() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let first = makeController(fileURL: url)
        first.beginNewEvent(start: date("2028-02-28"), allDay: true)
        first.draft?.setEnd(date("2028-02-29"))
        XCTAssertTrue(first.commitDraft())
        let id = try XCTUnwrap(first.selectedEventID)

        let second = makeController(fileURL: url)
        let event = try XCTUnwrap(second.store.event(id: id))
        XCTAssertTrue(event.isAllDay)
        XCTAssertEqual(event.startDate, date("2028-02-28"))
        XCTAssertEqual(event.endDate, date("2028-03-01"))
    }

    func testCorruptFileIsMovedAsideNotLost() throws {
        let url = temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: url)

        let controller = makeController(seed: true, fileURL: url)
        let aside = try XCTUnwrap(controller.store.recoveredCorruptFile)
        XCTAssertEqual(try String(contentsOf: aside, encoding: .utf8), "{ not json")
        XCTAssertNotNil(controller.store.lastError)
        XCTAssertFalse(controller.store.events.isEmpty, "falls back to sample data")
    }
}

final class SearchTests: XCTestCase {
    private func seededController() throws -> CalendarController {
        let controller = makeController()
        let id = controller.defaultCalendarID
        let store = controller.store
        try store.addEvent(CalendarEvent(calendarID: id, title: "Design Review", startDate: date("2026-10-22 14:00"),
                                         endDate: date("2026-10-22 15:00"), location: "Conference Room B"))
        try store.addEvent(CalendarEvent(calendarID: id, title: "Lunch", startDate: date("2026-10-20 12:00"),
                                         endDate: date("2026-10-20 13:00"), location: "Café Milano",
                                         notes: "review the menu"))
        try store.addEvent(CalendarEvent(calendarID: id, title: "Gym", startDate: date("2026-09-01 18:00"),
                                         endDate: date("2026-09-01 19:00")))
        return controller
    }

    func testMatchesTitleLocationNotesChronologically() throws {
        let controller = try seededController()
        controller.searchText = "review"
        XCTAssertTrue(controller.isSearching)
        let results = controller.searchResults
        XCTAssertEqual(results.map(\.event.title), ["Lunch", "Design Review"])
        XCTAssertEqual(results[0].matchedFields, [.notes])
        XCTAssertEqual(results[1].matchedFields, [.title])
        XCTAssertEqual(SearchField.notes.tokenText("review"), "Notes contain “review”")
    }

    func testCaseAndDiacriticInsensitive() throws {
        let controller = try seededController()
        XCTAssertEqual(controller.store.search("CAFE").map(\.event.title), ["Lunch"])
        XCTAssertEqual(controller.store.search("café").first?.matchedFields, [.location])
    }

    func testAllTermsMustMatch() throws {
        let controller = try seededController()
        XCTAssertEqual(controller.store.search("design room").map(\.event.title), ["Design Review"])
        XCTAssertTrue(controller.store.search("design gym").isEmpty)
    }

    func testEmptyQueryAndNoMatch() throws {
        let controller = try seededController()
        controller.searchText = "   "
        XCTAssertFalse(controller.isSearching)
        XCTAssertTrue(controller.searchResults.isEmpty)
        XCTAssertTrue(controller.store.search("zzz-no-match").isEmpty)
    }

    func testRevealNavigatesAndSelects() throws {
        let controller = try seededController()
        let gym = try XCTUnwrap(controller.store.search("gym").first)
        controller.reveal(gym.event.id)
        XCTAssertEqual(controller.displayedDate, date("2026-09-01"))
        XCTAssertEqual(controller.selectedEventID, gym.event.id)
        XCTAssertEqual(controller.headerTitle.bold, "September")
    }
}
