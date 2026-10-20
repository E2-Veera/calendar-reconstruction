import CalendarCore
import SwiftUI

/// Week and day views: day headers, an "all-day" strip with spanning bars, and a 24-hour grid
/// with side-by-side overlapping events and a current-time line.
struct TimeGridView: View {
    let controller: CalendarController
    let days: [Date]
    @Environment(\.isStaticRender) private var isStaticRender

    static let hourHeight: CGFloat = 46
    static let gutter: CGFloat = 58
    /// Hours shown by the non-scrolling offscreen render.
    static let staticHours = 8..<20

    var body: some View {
        let math = controller.math
        let range = DateInterval(start: days[0], end: math.addingDays(1, to: days.last!))
        let events = controller.store.events(in: range)

        VStack(spacing: 0) {
            if days.count > 1 { dayHeaders }
            allDayStrip(events)
            Rectangle().fill(Theme.allDayDivider).frame(height: 1)
            if isStaticRender {
                grid(events)
                    .offset(y: -CGFloat(Self.staticHours.lowerBound) * Self.hourHeight)
                    .frame(height: CGFloat(Self.staticHours.count) * Self.hourHeight, alignment: .top)
                    .clipped()
                Spacer(minLength: 0)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) { grid(events) }
                        .onAppear { proxy.scrollTo(7, anchor: .top) }
                }
            }
        }
        .accessibilityLabel(days.count > 1 ? "Week Calendar Area" : "Day Calendar Area")
    }

    private var dayHeaders: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.gutter, height: 1)
            ForEach(days, id: \.self) { day in
                let isToday = controller.math.isSameDay(day, controller.today)
                HStack(spacing: 4) {
                    Spacer()
                    Text(controller.math.formatted(day, template: "EEE"))
                    Text(controller.math.formatted(day, template: "d"))
                        .fontWeight(isToday ? .semibold : .regular)
                        .foregroundStyle(isToday ? Theme.activeDateLabel : .primary)
                        .padding(.horizontal, isToday ? 6 : 0)
                        .background(isToday ? Theme.accent : .clear, in: Capsule())
                }
                .font(.system(size: 13))
                .padding(.trailing, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { controller.showDay(day) }
            }
        }
    }

    private func allDayStrip(_ events: [CalendarEvent]) -> some View {
        let spans = EventLayoutEngine.layoutSpanningEvents(events, days: days, calendar: controller.calendar)
        let lanes = max(1, (spans.map(\.lane).max() ?? -1) + 1)
        return HStack(spacing: 0) {
            Text("all-day")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: Self.gutter - 8, alignment: .trailing)
                .padding(.trailing, 8)
            GeometryReader { geo in
                let columnWidth = geo.size.width / CGFloat(days.count)
                ZStack(alignment: .topLeading) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2, coordinateSpace: .local) { location in
                            let index = min(days.count - 1, max(0, Int(location.x / columnWidth)))
                            controller.beginNewEvent(start: days[index], allDay: true)
                        }
                    ForEach(spans, id: \.event.id) { span in
                        let event = span.event
                        let selected = controller.selectedEventID == event.id
                        let color = controller.color(for: event)
                        Text(event.displayTitle)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                            .frame(width: CGFloat(span.lastIndex - span.firstIndex + 1) * columnWidth - 4, height: 18,
                                   alignment: .leading)
                            .foregroundStyle(selected ? .white : .primary)
                            .background(selected ? color : color.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
                            .eventInteractions(controller, event)
                            .offset(x: CGFloat(span.firstIndex) * columnWidth + 2, y: CGFloat(span.lane) * 20 + 2)
                    }
                }
            }
        }
        .frame(height: CGFloat(min(lanes, 4)) * 20 + 4)
    }

    private func grid(_ events: [CalendarEvent]) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    hourRow(hour).frame(height: Self.hourHeight).id(hour)
                }
            }
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.gutter)
                ForEach(days, id: \.self) { day in
                    DayColumn(controller: controller, day: day, events: events)
                        .overlay(alignment: .leading) { Rectangle().fill(Theme.allDayDivider).frame(width: 1) }
                }
            }
        }
        .frame(height: 24 * Self.hourHeight)
    }

    private func hourRow(_ hour: Int) -> some View {
        HStack(spacing: 0) {
            Text(hour == 0 ? "" : Self.hourLabel(hour, math: controller.math))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: Self.gutter - 8, alignment: .trailing)
                .padding(.trailing, 8)
                .offset(y: -6)
                .frame(maxHeight: .infinity, alignment: .top)
            ForEach(days, id: \.self) { day in
                VStack(spacing: 0) {
                    Rectangle().fill(gridlineColor(day: day, hour: hour)).frame(height: 1)
                    Spacer(minLength: 0)
                }
                .background(controller.math.isWeekend(day) ? Theme.weekendBackground : .clear)
            }
        }
    }

    private func gridlineColor(day: Date, hour: Int) -> Color {
        let work = Theme.workHours.contains(hour)
        if controller.math.isSameDay(day, controller.today) { return work ? Theme.gridTodayWork : Theme.gridTodayOff }
        if controller.math.isWeekend(day) { return work ? Theme.gridWeekendWork : Theme.gridWeekendOff }
        return work ? Theme.gridWeekdayWork : Theme.gridWeekdayOff
    }

    static func hourLabel(_ hour: Int, math: CalendarMath) -> String {
        let date = math.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())!
        let uses12Hour = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: math.calendar.locale ?? .current)?
            .contains("a") ?? false
        return uses12Hour ? math.formatted(date, template: "j") : math.formatted(date, template: "HH:mm")
    }
}

private struct DayColumn: View {
    let controller: CalendarController
    let day: Date
    let events: [CalendarEvent]

    var body: some View {
        let hourHeight = TimeGridView.hourHeight
        let layouts = EventLayoutEngine.layoutTimedEvents(events, on: day, calendar: controller.calendar)
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, coordinateSpace: .local) { location in
                        // Double-click an empty slot: new one-hour event snapped to 15 minutes.
                        let minutes = max(0, min(23 * 60 + 45, Int(location.y / hourHeight * 60) / 15 * 15))
                        controller.selectDay(day)
                        controller.beginNewEvent(start: controller.math.startOfDay(day).addingTimeInterval(Double(minutes * 60)))
                    }
                    .onTapGesture {
                        controller.selectDay(day)
                        controller.selectEvent(nil)
                    }
                ForEach(layouts, id: \.event.id) { layout in
                    let columnWidth = (geo.size.width - 6) / CGFloat(layout.columnCount)
                    let height = max(18, CGFloat(layout.endMinute - layout.startMinute) / 60 * hourHeight - 2)
                    TimedEventBlock(controller: controller, event: layout.event, height: height)
                        .frame(width: columnWidth - 2, height: height)
                        .offset(x: CGFloat(layout.column) * columnWidth + 2,
                                y: CGFloat(layout.startMinute) / 60 * hourHeight + 1)
                }
                if controller.math.isSameDay(day, controller.currentTime) {
                    let minutes = controller.currentTime.timeIntervalSince(controller.math.startOfDay(day)) / 60
                    HStack(spacing: 0) {
                        Circle().fill(Theme.accent).frame(width: 8, height: 8)
                        Rectangle().fill(Theme.accent).frame(height: 1.5)
                    }
                    .offset(x: -4, y: CGFloat(minutes) / 60 * hourHeight - 4)
                    .allowsHitTesting(false)
                }
            }
        }
    }
}

private struct TimedEventBlock: View {
    let controller: CalendarController
    let event: CalendarEvent
    let height: CGFloat

    var body: some View {
        let selected = controller.selectedEventID == event.id
        let color = controller.color(for: event)
        VStack(alignment: .leading, spacing: 1) {
            Text(event.displayTitle).font(.system(size: 11, weight: .semibold)).lineLimit(height > 40 ? 2 : 1)
            if height > 30 {
                Text(controller.math.timeString(event.startDate)).font(.system(size: 10))
            }
            if height > 52, !event.location.isEmpty {
                Text(event.location).font(.system(size: 10)).lineLimit(1)
            }
        }
        .foregroundStyle(selected ? .white : .primary)
        .padding(.leading, 7)
        .padding(.trailing, 3)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(selected ? color : color.opacity(0.2))
        .overlay(alignment: .leading) { Rectangle().fill(color).frame(width: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .eventInteractions(controller, event)
    }
}

/// Day view: time grid plus a side panel with a mini month and the selected event's details.
struct DayView: View {
    let controller: CalendarController

    var body: some View {
        HStack(spacing: 0) {
            TimeGridView(controller: controller, days: [controller.displayedDate])
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                MiniMonthView(controller: controller, month: controller.displayedDate, showsAdjacentDays: true,
                              selectedDay: controller.displayedDate) { controller.go(to: $0) }
                Divider()
                if let event = controller.selectedEvent {
                    EventDetails(controller: controller, event: event)
                } else {
                    Text("No Event Selected").foregroundStyle(.secondary).frame(maxWidth: .infinity)
                        .padding(.top, 20)
                }
                Spacer()
            }
            .padding(14)
            .frame(width: 280)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

struct EventDetails: View {
    let controller: CalendarController
    let event: CalendarEvent
    @Environment(\.isStaticRender) private var isStaticRender

    var body: some View {
        let math = controller.math
        VStack(alignment: .leading, spacing: 8) {
            Text(event.displayTitle).font(.system(size: 18, weight: .bold))
            if !event.location.isEmpty { Text(event.location).foregroundStyle(.secondary) }
            HStack(spacing: 6) {
                Circle().fill(controller.color(for: event)).frame(width: 9, height: 9)
                Text(controller.store.calendar(id: event.calendarID)?.name ?? "")
            }
            .font(.system(size: 12))
            Text(math.formatted(event.startDate, template: "EEEEdMMMMy")).font(.system(size: 12))
            Text(controller.timeRange(event)).font(.system(size: 12))
            if !event.notes.isEmpty {
                Divider()
                Text(event.notes).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if !isStaticRender {
                HStack {
                    Button("Edit…") { controller.beginEditing(event.id) }
                    Button("Delete", role: .destructive) { controller.deleteEvent(event.id) }
                }
                .padding(.top, 4)
            }
        }
    }
}

/// Year view: twelve mini months with Calendar.app's busy-day heat map colours.
struct YearView: View {
    let controller: CalendarController
    @Environment(\.isStaticRender) private var isStaticRender

    var body: some View {
        let math = controller.math
        let year = controller.calendar.dateInterval(of: .year, for: controller.displayedDate)!
        let months = (0..<12).map { controller.calendar.date(byAdding: .month, value: $0, to: year.start)! }
        let counts = busyCounts(in: year)
        let grid = LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 24, alignment: .top), count: 4),
                             spacing: 24) {
            ForEach(months, id: \.self) { month in
                MiniMonthView(controller: controller, month: month, showsAdjacentDays: false, selectedDay: nil,
                              heat: counts, highlightsCurrentMonthTitle: math.isInSameMonth(month, as: controller.today),
                              onSelect: { controller.selectDay($0) }, onOpen: { controller.showDay($0) })
            }
        }
        .padding(24)
        Group {
            if isStaticRender { VStack { grid; Spacer(minLength: 0) } } else { ScrollView { grid } }
        }
        .accessibilityLabel("Year Calendar Area")
    }

    private func busyCounts(in year: DateInterval) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        let math = controller.math
        for event in controller.store.events(in: year) {
            var day = math.startOfDay(max(event.startDate, year.start))
            let end = min(event.endDate, year.end)
            repeat {
                counts[day, default: 0] += 1
                day = math.addingDays(1, to: day)
            } while day < end
        }
        return counts
    }
}

struct MiniMonthView: View {
    let controller: CalendarController
    let month: Date
    var showsAdjacentDays = true
    var selectedDay: Date?
    var heat: [Date: Int]? = nil
    var highlightsCurrentMonthTitle = false
    var onSelect: (Date) -> Void
    var onOpen: ((Date) -> Void)? = nil

    init(controller: CalendarController, month: Date, showsAdjacentDays: Bool = true, selectedDay: Date? = nil,
         heat: [Date: Int]? = nil, highlightsCurrentMonthTitle: Bool = false,
         onSelect: @escaping (Date) -> Void, onOpen: ((Date) -> Void)? = nil) {
        self.controller = controller
        self.month = month
        self.showsAdjacentDays = showsAdjacentDays
        self.selectedDay = selectedDay
        self.heat = heat
        self.highlightsCurrentMonthTitle = highlightsCurrentMonthTitle
        self.onSelect = onSelect
        self.onOpen = onOpen
    }

    var body: some View {
        let math = controller.math
        VStack(alignment: .leading, spacing: 4) {
            Text(math.formatted(month, template: heat == nil ? "MMMMy" : "MMMM"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(highlightsCurrentMonthTitle ? Theme.accent : .primary)
            Grid(horizontalSpacing: 0, verticalSpacing: 2) {
                GridRow {
                    ForEach(Array(math.orderedWeekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                        Text(String(symbol.prefix(1))).font(.system(size: 10)).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(Array(math.monthGrid(for: month).enumerated()), id: \.offset) { _, week in
                    GridRow {
                        ForEach(week, id: \.self) { day in cell(day) }
                    }
                }
            }
        }
        // Keep natural height so months with fewer weeks don't stretch their rows.
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func cell(_ day: Date) -> some View {
        let math = controller.math
        let inMonth = math.isInSameMonth(day, as: month)
        let isToday = math.isSameDay(day, controller.today)
        let isSelected = selectedDay.map { math.isSameDay($0, day) } ?? false
        let level = min(3, heat?[day] ?? 0)
        if !inMonth && !showsAdjacentDays {
            Color.clear.frame(maxWidth: .infinity, minHeight: 20)
        } else {
            Text(math.formatted(day, template: "d"))
                .font(.system(size: 11, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Theme.activeDateLabel
                                 : level > 0 && inMonth ? Theme.heatmap[level - 1].text
                                 : inMonth ? Color.primary : Color.secondary.opacity(0.5))
                .frame(width: 22, height: 20)
                .background {
                    if isToday {
                        Circle().fill(Theme.accent)
                    } else if isSelected {
                        Circle().fill(Color.gray.opacity(0.3))
                    } else if level > 0 && inMonth {
                        RoundedRectangle(cornerRadius: 4).fill(Theme.heatmap[level - 1].background)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { (onOpen ?? onSelect)(day) }
                .onTapGesture { onSelect(day) }
        }
    }
}
