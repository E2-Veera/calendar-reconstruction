import CalendarCore
import SwiftUI

/// Month view: weekday header, 4–6 week rows, spanning bars for all-day/multi-day events,
/// dot + title + time for timed events, and an overflow line when a day is full.
struct MonthView: View {
    let controller: CalendarController

    var body: some View {
        let math = controller.math
        let rows = math.monthGrid(for: controller.displayedDate)
        let interval = DateInterval(start: rows[0][0], end: math.addingDays(1, to: rows.last!.last!))
        let events = controller.store.events(in: interval)

        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(math.orderedWeekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 8)
                }
            }
            .padding(.vertical, 4)
            Rectangle().fill(Theme.allDayDivider).frame(height: 1)
            GeometryReader { geo in
                let rowHeight = geo.size.height / CGFloat(rows.count)
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, days in
                        MonthWeekRow(controller: controller, days: days, events: events,
                                     cellWidth: geo.size.width / 7, height: rowHeight)
                    }
                }
            }
        }
        .accessibilityLabel("Month Calendar Area")
    }
}

private struct MonthWeekRow: View {
    let controller: CalendarController
    let days: [Date]
    let events: [CalendarEvent]
    let cellWidth: CGFloat
    let height: CGFloat

    static let lineHeight: CGFloat = 18
    static let headerHeight: CGFloat = 26

    var body: some View {
        let calendar = controller.calendar
        let spanning = EventLayoutEngine.layoutSpanningEvents(events, days: days, calendar: calendar)
        let capacity = max(0, Int((height - Self.headerHeight - 2) / Self.lineHeight))
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let dayInterval = controller.math.dayInterval(day)
                let timed = events.filter { !$0.isAllDay && !$0.isMultiDay(calendar: calendar) && $0.overlaps(dayInterval) }
                let slots = EventLayoutEngine.monthCellSlots(dayIndex: index, spanning: spanning, timed: timed,
                                                             capacity: capacity)
                MonthDayCell(controller: controller, day: day, slots: slots, cellWidth: cellWidth)
                    .frame(width: cellWidth, height: height)
                    // Earlier cells draw above later ones so a bar's title can run across the span.
                    .zIndex(Double(days.count - index))
            }
        }
    }
}

private struct MonthDayCell: View {
    let controller: CalendarController
    let day: Date
    let slots: [MonthCellSlot]
    let cellWidth: CGFloat

    var body: some View {
        let math = controller.math
        let inMonth = math.isInSameMonth(day, as: controller.displayedDate)
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Spacer()
                dayLabel(inMonth: inMonth)
            }
            .frame(height: MonthWeekRow.headerHeight - 2)
            .padding(.trailing, 6)
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                slotView(slot).frame(height: MonthWeekRow.lineHeight - 2)
            }
            Spacer(minLength: 0)
        }
        .background(math.isWeekend(day) ? Theme.weekendBackground : Color.clear)
        .overlay(alignment: .trailing) { Rectangle().fill(Theme.allDayDivider).frame(width: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.allDayDivider).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            controller.selectDay(day)
            controller.beginNewEvent(start: controller.calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day))
        }
        .onTapGesture {
            controller.selectDay(day)
            controller.selectEvent(nil)
        }
    }

    @ViewBuilder
    private func dayLabel(inMonth: Bool) -> some View {
        let math = controller.math
        let isToday = math.isSameDay(day, controller.today)
        let isFirst = controller.calendar.component(.day, from: day) == 1
        let text = isFirst ? math.formatted(day, template: "dMMM") : math.formatted(day, template: "d")
        if isToday {
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.activeDateLabel)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Theme.accent, in: Capsule())
        } else {
            Text(text)
                .font(.system(size: 13, weight: isFirst ? .semibold : .regular))
                .foregroundStyle(inMonth ? .primary : .tertiary)
        }
    }

    @ViewBuilder
    private func slotView(_ slot: MonthCellSlot) -> some View {
        switch slot {
        case .empty:
            Color.clear
        case .more(let count):
            Text("\(count) more…")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        case .timed(let event):
            let selected = controller.selectedEventID == event.id
            let color = controller.color(for: event)
            HStack(spacing: 4) {
                Circle().fill(selected ? .white : color).frame(width: 7, height: 7)
                Text(event.displayTitle).font(.system(size: 11)).lineLimit(1)
                Spacer(minLength: 2)
                if cellWidth > 150 {  // narrow cells show titles only
                    Text(controller.math.timeString(event.startDate))
                        .font(.system(size: 11))
                        .foregroundStyle(selected ? .white : .secondary)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 4)
            .foregroundStyle(selected ? .white : .primary)
            .background(selected ? color : .clear, in: RoundedRectangle(cornerRadius: 4))
            .padding(.horizontal, 3)
            .eventInteractions(controller, event)
        case let .bar(layout, showsTitle, isFirst, isLast):
            let event = layout.event
            let selected = controller.selectedEventID == event.id
            let color = controller.color(for: event)
            UnevenRoundedRectangle(topLeadingRadius: isFirst ? 4 : 0, bottomLeadingRadius: isFirst ? 4 : 0,
                                   bottomTrailingRadius: isLast ? 4 : 0, topTrailingRadius: isLast ? 4 : 0)
                .fill(selected ? color : color.opacity(0.25))
                .overlay(alignment: .leading) {
                    if showsTitle {
                        let span = CGFloat(layout.lastIndex - layout.firstIndex + 1)
                        Text(event.displayTitle)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(selected ? .white : .primary)
                            .padding(.leading, 6)
                            .frame(width: span * cellWidth - 12, alignment: .leading)
                            .fixedSize()
                    }
                }
                .padding(.leading, isFirst ? 4 : 0)
                .padding(.trailing, isLast ? 4 : 0)
                .eventInteractions(controller, event)
        }
    }
}

extension View {
    /// Click selects, double-click edits, context menu offers Edit/Delete.
    func eventInteractions(_ controller: CalendarController, _ event: CalendarEvent) -> some View {
        contentShape(Rectangle())
            .onTapGesture(count: 2) { controller.beginEditing(event.id) }
            .onTapGesture { controller.selectEvent(event.id) }
            .contextMenu {
                Button("Edit Event") { controller.beginEditing(event.id) }
                Button("Delete") { controller.deleteEvent(event.id) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
    }
}
