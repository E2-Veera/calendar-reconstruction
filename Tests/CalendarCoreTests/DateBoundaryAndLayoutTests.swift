import CalendarCore
import XCTest

/// Test area 7: month boundaries and leap years; plus month/week layout rules.
final class DateBoundaryTests: XCTestCase {
    let math = CalendarMath(calendar: makeCalendar())

    func testLeapYearRule() {
        XCTAssertTrue(CalendarMath.isLeapYear(2024))
        XCTAssertTrue(CalendarMath.isLeapYear(2028))
        XCTAssertTrue(CalendarMath.isLeapYear(2000))
        XCTAssertFalse(CalendarMath.isLeapYear(1900))
        XCTAssertFalse(CalendarMath.isLeapYear(2100))
        XCTAssertFalse(CalendarMath.isLeapYear(2026))
    }

    func testFebruaryLengths() {
        XCTAssertEqual(math.numberOfDays(inMonthOf: date("2028-02-10")), 29)
        XCTAssertEqual(math.numberOfDays(inMonthOf: date("2026-02-10")), 28)
        XCTAssertEqual(math.numberOfDays(inMonthOf: date("2000-02-10")), 29)
        XCTAssertEqual(math.numberOfDays(inMonthOf: date("2100-02-10")), 28)
    }

    func testMonthStepClampsDay() {
        XCTAssertEqual(math.step(date("2028-01-31"), mode: .month, by: 1), date("2028-02-29"))
        XCTAssertEqual(math.step(date("2026-01-31"), mode: .month, by: 1), date("2026-02-28"))
        XCTAssertEqual(math.step(date("2026-03-31"), mode: .month, by: -1), date("2026-02-28"))
        XCTAssertEqual(math.step(date("2028-02-29"), mode: .year, by: 1), date("2029-02-28"))
    }

    func testDayStepsCrossMonthAndYearBoundaries() {
        XCTAssertEqual(math.step(date("2026-10-31"), mode: .day, by: 1), date("2026-11-01"))
        XCTAssertEqual(math.step(date("2026-12-31"), mode: .day, by: 1), date("2027-01-01"))
        XCTAssertEqual(math.step(date("2028-02-28"), mode: .day, by: 1), date("2028-02-29"))
        XCTAssertEqual(math.step(date("2028-02-29"), mode: .day, by: 1), date("2028-03-01"))
        XCTAssertEqual(math.step(date("2026-03-01"), mode: .day, by: -1), date("2026-02-28"))
        XCTAssertEqual(math.step(date("2026-12-28"), mode: .week, by: 1), date("2027-01-04"))
    }

    func testMonthGridCoversWholeMonthInFullWeeks() {
        for (month, expectedRows) in [("2026-10-01", 5), ("2026-02-01", 4), ("2026-08-01", 6), ("2028-02-01", 5)] {
            let grid = math.monthGrid(for: date(month))
            XCTAssertEqual(grid.count, expectedRows, month)
            XCTAssertTrue(grid.allSatisfy { $0.count == 7 })
            let all = grid.flatMap { $0 }
            XCTAssertEqual(math.calendar.component(.weekday, from: all.first!), 1, "rows start on Sunday")
            let inMonth = all.filter { math.isInSameMonth($0, as: date(month)) }
            XCTAssertEqual(inMonth.count, math.numberOfDays(inMonthOf: date(month)), month)
        }
        // February 2026 starts on a Sunday and has 28 days: exactly four rows, no adjacent days.
        XCTAssertEqual(math.monthGrid(for: date("2026-02-01")).first?.first, date("2026-02-01"))
        // Leap February 2028 contains the 29th.
        XCTAssertTrue(math.monthGrid(for: date("2028-02-01")).flatMap { $0 }.contains(date("2028-02-29")))
    }

    func testMonthGridWithMondayFirst() {
        let monday = CalendarMath(calendar: makeCalendar(firstWeekday: 2))
        let grid = monday.monthGrid(for: date("2026-11-01"))  // Nov 1 2026 is a Sunday
        XCTAssertEqual(grid.first?.first, date("2026-10-26"))
        XCTAssertEqual(grid.first?.last, date("2026-11-01"))
        XCTAssertEqual(grid.count, 6)
    }

    func testEventOnLastDayOfMonthAppearsInBothMonthGrids() throws {
        let controller = makeController()
        try controller.store.addEvent(CalendarEvent(calendarID: controller.defaultCalendarID, title: "Edge",
                                                    startDate: date("2026-10-31 23:30"), endDate: date("2026-11-01 00:30")))
        controller.go(to: date("2026-10-15"))
        XCTAssertEqual(controller.visibleEvents.map(\.title), ["Edge"])
        controller.goNext()  // November grid starts with Oct 25–31
        XCTAssertEqual(controller.visibleEvents.map(\.title), ["Edge"])
        XCTAssertEqual(controller.events(on: date("2026-10-31")).count, 1)
        XCTAssertEqual(controller.events(on: date("2026-11-01")).count, 1)
    }

    func testLeapDayEvent() throws {
        let controller = makeController()
        try controller.store.addEvent(CalendarEvent(calendarID: controller.defaultCalendarID, title: "Leap",
                                                    startDate: date("2028-02-29"), endDate: date("2028-03-01"), isAllDay: true))
        XCTAssertEqual(controller.events(on: date("2028-02-29")).map(\.title), ["Leap"])
        XCTAssertTrue(controller.events(on: date("2028-03-01")).isEmpty)
        XCTAssertTrue(controller.events(on: date("2028-02-28")).isEmpty)
    }

    func testDaylightSavingDayHas23Hours() {
        let newYork = CalendarMath(calendar: makeCalendar(timeZone: "America/New_York"))
        let springForward = date("2026-03-08", newYork.calendar)
        XCTAssertEqual(newYork.dayInterval(springForward).duration, 23 * 3600)
        XCTAssertEqual(newYork.step(springForward, mode: .day, by: 1), date("2026-03-09", newYork.calendar))
    }
}

final class LayoutTests: XCTestCase {
    let calendar = makeCalendar()
    let cal = UUID()

    private func event(_ title: String, _ start: String, _ end: String, allDay: Bool = false) -> CalendarEvent {
        CalendarEvent(calendarID: cal, title: title, startDate: date(start), endDate: date(end), isAllDay: allDay)
    }

    func testOverlappingEventsShareWidth() {
        let events = [event("A", "2026-10-20 11:00", "2026-10-20 12:00"),
                      event("B", "2026-10-20 11:30", "2026-10-20 12:30"),
                      event("C", "2026-10-20 14:00", "2026-10-20 15:00")]
        let layout = EventLayoutEngine.layoutTimedEvents(events, on: date("2026-10-20"), calendar: calendar)
        let byTitle = Dictionary(uniqueKeysWithValues: layout.map { ($0.event.title, $0) })
        XCTAssertEqual(byTitle["A"]?.column, 0)
        XCTAssertEqual(byTitle["B"]?.column, 1)
        XCTAssertEqual(byTitle["A"]?.columnCount, 2)
        XCTAssertEqual(byTitle["C"]?.columnCount, 1)
        XCTAssertEqual(byTitle["A"]?.startMinute, 660)
        XCTAssertEqual(byTitle["B"]?.endMinute, 750)
    }

    func testOvernightEventIsClippedToEachDay() {
        let overnight = event("Night", "2026-10-20 23:00", "2026-10-21 01:00")
        let first = EventLayoutEngine.layoutTimedEvents([overnight], on: date("2026-10-20"), calendar: calendar)
        XCTAssertTrue(first.isEmpty, "multi-day timed events are drawn as bars, not in the grid")
        XCTAssertTrue(overnight.isMultiDay(calendar: calendar))
    }

    func testSpanningLanesAndContinuation() {
        let week = CalendarMath(calendar: calendar).weekDays(containing: date("2026-10-20"))  // Oct 18–24
        let events = [event("Offsite", "2026-10-16", "2026-10-21", allDay: true),
                      event("Trip", "2026-10-20", "2026-10-27", allDay: true),
                      event("Birthday", "2026-10-22", "2026-10-23", allDay: true)]
        let spans = EventLayoutEngine.layoutSpanningEvents(events, days: week, calendar: calendar)
        let byTitle = Dictionary(uniqueKeysWithValues: spans.map { ($0.event.title, $0) })
        XCTAssertEqual(byTitle["Offsite"]?.firstIndex, 0)
        XCTAssertEqual(byTitle["Offsite"]?.lastIndex, 2)
        XCTAssertEqual(byTitle["Offsite"]?.continuesBefore, true)
        XCTAssertEqual(byTitle["Trip"]?.lane, 1)
        XCTAssertEqual(byTitle["Trip"]?.continuesAfter, true)
        XCTAssertEqual(byTitle["Birthday"]?.lane, 0, "reuses the lane freed by Offsite")
    }

    func testMonthCellOverflowShowsMore() {
        let timed = (0..<5).map { event("E\($0)", "2026-10-28 0\($0 + 1):00", "2026-10-28 0\($0 + 1):30") }
        let slots = EventLayoutEngine.monthCellSlots(dayIndex: 3, spanning: [], timed: timed, capacity: 3)
        XCTAssertEqual(slots.count, 3)
        XCTAssertEqual(slots.last, .more(3))
        let roomy = EventLayoutEngine.monthCellSlots(dayIndex: 3, spanning: [], timed: timed, capacity: 5)
        XCTAssertFalse(roomy.contains(.more(0)))
        XCTAssertEqual(roomy.count, 5)
    }
}

/// Test area 1 (logic part): the first launch is immediately demonstrable.
final class LaunchStateTests: XCTestCase {
    func testSampleDataPopulatesEveryView() {
        let controller = makeController(seed: true)
        XCTAssertEqual(controller.store.calendars.map(\.name), ["Home", "Work", "Family", "Personal"])
        XCTAssertEqual(Set(controller.store.calendars.map(\.colorHex)).count, 4, "distinct colours")
        for mode in CalendarViewMode.allCases {
            controller.setMode(mode)
            XCTAssertFalse(controller.visibleEvents.isEmpty, "\(mode) has events")
        }
        XCTAssertTrue(controller.store.events.contains { $0.isAllDay })
        XCTAssertTrue(controller.store.events.contains { $0.isMultiDay(calendar: controller.calendar) })
    }
}
