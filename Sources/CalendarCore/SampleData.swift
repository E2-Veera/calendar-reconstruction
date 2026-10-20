import Foundation

/// First-launch demo content, positioned relative to "today" so every view has something to show.
public enum SampleData {
    public static func make(now: Date, calendar: Calendar) -> (calendars: [CalendarInfo], events: [CalendarEvent]) {
        let home = CalendarInfo(name: "Home", colorHex: "#1BADF8")
        let work = CalendarInfo(name: "Work", colorHex: "#FF2968")
        let family = CalendarInfo(name: "Family", colorHex: "#CC73E1")
        let personal = CalendarInfo(name: "Personal", colorHex: "#63DA38")

        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: today)! }
        func at(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day(offset))!
        }
        func timed(_ cal: CalendarInfo, _ title: String, _ start: Date, minutes: Int,
                   location: String = "", notes: String = "") -> CalendarEvent {
            CalendarEvent(calendarID: cal.id, title: title, startDate: start,
                          endDate: start.addingTimeInterval(TimeInterval(minutes * 60)),
                          location: location, notes: notes)
        }
        func allDay(_ cal: CalendarInfo, _ title: String, from first: Date, days: Int,
                    location: String = "", notes: String = "") -> CalendarEvent {
            CalendarEvent(calendarID: cal.id, title: title, startDate: first,
                          endDate: calendar.date(byAdding: .day, value: days, to: first)!,
                          isAllDay: true, location: location, notes: notes)
        }

        let month = calendar.dateInterval(of: .month, for: now)!
        let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: month.end)!

        var events: [CalendarEvent] = [
            timed(work, "Team Stand-up", at(0, 9, 30), minutes: 15, location: "Zoom", notes: "Daily sync with the calendar POC team."),
            timed(work, "Product Sync", at(0, 11), minutes: 60, location: "Room 4A"),
            timed(work, "Customer Call", at(0, 11, 30), minutes: 60, location: "Phone", notes: "Overlaps Product Sync to demonstrate side-by-side layout."),
            timed(work, "Design Review", at(0, 14), minutes: 60, location: "Conference Room B",
                  notes: "Compare the reconstructed month view with Calendar.app."),
            timed(home, "Lunch with Alex", at(1, 12, 30), minutes: 60, location: "Café Milano"),
            timed(personal, "Gym", at(1, 18), minutes: 60, location: "Fitness First"),
            timed(work, "Team Stand-up", at(1, 9, 30), minutes: 15, location: "Zoom"),
            timed(family, "Dentist Appointment", at(2, 16), minutes: 45, location: "Smile Dental Clinic",
                  notes: "Bring the insurance card."),
            timed(work, "Quarterly Planning", at(-2, 10), minutes: 120, location: "Board Room",
                  notes: "Discuss the quarterly roadmap and hiring plan."),
            timed(personal, "Book Club", at(-6, 19), minutes: 90, location: "City Library",
                  notes: "Discuss “The Pragmatic Programmer”."),
            timed(home, "Grocery Run", at(4, 17, 30), minutes: 45, location: "Supermarket"),
            allDay(family, "Mom’s Birthday", from: day(3), days: 1, notes: "Call in the morning; order cake."),
            allDay(work, "Company Offsite", from: day(5), days: 2, location: "Lonavala",
                   notes: "Two-day offsite — spans multiple days in month and week views."),
            allDay(work, "Month-end Report Due", from: lastDayOfMonth, days: 1),
            timed(home, "Rent Due", calendar.date(bySettingHour: 9, minute: 0, second: 0, of: month.end)!, minutes: 30),
        ]
        // A busy day to demonstrate the month view's "more" overflow.
        for (index, title) in ["Code Review", "1:1 with Manager", "Sprint Demo", "Retro", "Release Prep"].enumerated() {
            events.append(timed(work, title, at(8, 9 + index * 2), minutes: 45, location: "Room 4A"))
        }
        return ([home, work, family, personal], events)
    }
}
