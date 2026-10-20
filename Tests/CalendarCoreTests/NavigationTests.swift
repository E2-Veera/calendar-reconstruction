import CalendarCore
import XCTest

/// Test area 2: navigating between dates and calendar views.
final class NavigationTests: XCTestCase {
    func testStartsOnTodayInMonthView() {
        let controller = makeController()
        XCTAssertEqual(controller.mode, .month)
        XCTAssertEqual(controller.displayedDate, date("2026-10-20"))
        XCTAssertEqual(controller.headerTitle.bold, "October")
        XCTAssertEqual(controller.headerTitle.regular, "2026")
    }

    func testNextPreviousInEachMode() {
        let controller = makeController()
        controller.goNext()
        XCTAssertEqual(controller.displayedDate, date("2026-11-20"))
        controller.goPrevious()
        controller.goPrevious()
        XCTAssertEqual(controller.displayedDate, date("2026-09-20"))

        controller.goToToday()
        controller.setMode(.week)
        controller.goNext()
        XCTAssertEqual(controller.displayedDate, date("2026-10-27"))

        controller.setMode(.day)
        controller.goPrevious()
        XCTAssertEqual(controller.displayedDate, date("2026-10-26"))

        controller.setMode(.year)
        controller.goNext()
        XCTAssertEqual(controller.displayedDate, date("2027-10-26"))
        XCTAssertEqual(controller.headerTitle.bold, "2027")
    }

    func testTodayReturnsFromAnywhere() {
        let controller = makeController()
        for _ in 0..<14 { controller.goNext() }
        XCTAssertNotEqual(controller.displayedDate, controller.today)
        controller.goToToday()
        XCTAssertEqual(controller.displayedDate, date("2026-10-20"))
        XCTAssertEqual(controller.selectedDay, date("2026-10-20"))
    }

    func testSwitchingViewsKeepsSelectedDay() {
        let controller = makeController()
        controller.selectDay(date("2026-10-08"))
        controller.setMode(.week)
        XCTAssertEqual(controller.visibleInterval.start, date("2026-10-04"))  // Sunday
        XCTAssertEqual(controller.visibleInterval.end, date("2026-10-11"))
        controller.setMode(.day)
        XCTAssertEqual(controller.visibleInterval, DateInterval(start: date("2026-10-08"), end: date("2026-10-09")))
    }

    func testWeekRespectsFirstWeekday() {
        let monday = CalendarMath(calendar: makeCalendar(firstWeekday: 2))
        let days = monday.weekDays(containing: date("2026-10-20"))
        XCTAssertEqual(days.first, date("2026-10-19"))
        XCTAssertEqual(days.last, date("2026-10-25"))
        XCTAssertEqual(monday.orderedWeekdaySymbols().first, "Mon")
    }

    func testWeekTitleSpanningMonthsAndYears() {
        let math = CalendarMath(calendar: makeCalendar())
        XCTAssertEqual(math.headerTitle(for: .week, date: date("2026-10-20")).bold, "October")
        let crossMonth = math.headerTitle(for: .week, date: date("2026-09-29"))  // Sep 27 – Oct 3
        XCTAssertEqual(crossMonth.bold, "Sep – Oct")
        XCTAssertEqual(crossMonth.regular, "2026")
        let crossYear = math.headerTitle(for: .week, date: date("2026-12-31"))  // Dec 27 – Jan 2
        XCTAssertEqual(crossYear.bold, "Dec 2026 – Jan")
        XCTAssertEqual(crossYear.regular, "2027")
    }

    func testGoToDateAndShowDay() {
        let controller = makeController()
        controller.go(to: date("2030-01-15 13:45"))
        XCTAssertEqual(controller.displayedDate, date("2030-01-15"))
        controller.showDay(date("2030-02-01"))
        XCTAssertEqual(controller.mode, .day)
        XCTAssertEqual(controller.displayedDate, date("2030-02-01"))
    }
}
