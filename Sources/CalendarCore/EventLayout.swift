import Foundation

/// Position of a timed event inside one day column of the week/day time grid.
public struct TimedEventLayout: Equatable, Sendable {
    public let event: CalendarEvent
    /// Minutes from the start of the day, clipped to 0...1440.
    public let startMinute: Double
    public let endMinute: Double
    public let column: Int
    public let columnCount: Int
}

/// A multi-day / all-day event's span inside one row of days (a week).
public struct SpanningEventLayout: Equatable, Sendable {
    public let event: CalendarEvent
    public let firstIndex: Int
    public let lastIndex: Int
    public let lane: Int
    public let continuesBefore: Bool
    public let continuesAfter: Bool
}

/// One drawable line inside a month-view day cell.
public enum MonthCellSlot: Equatable, Sendable {
    /// Segment of a spanning (all-day or multi-day) event bar.
    case bar(SpanningEventLayout, showsTitle: Bool, isFirstSegment: Bool, isLastSegment: Bool)
    /// Placeholder keeping lanes aligned across the week.
    case empty
    /// Timed single-day event (dot + title + time).
    case timed(CalendarEvent)
    /// "N more" overflow indicator (Calendar.app string: "More events hidden").
    case more(Int)
}

public enum EventLayoutEngine {
    /// Side-by-side columns for overlapping timed events (overlapping events share the width).
    public static func layoutTimedEvents(_ events: [CalendarEvent], on day: Date, calendar: Calendar,
                                         minimumMinutes: Double = 20) -> [TimedEventLayout] {
        let dayInterval = calendar.dateInterval(of: .day, for: day)!
        let dayLength = dayInterval.duration / 60
        typealias Item = (event: CalendarEvent, start: Double, end: Double)
        let candidates = events.filter { !$0.isAllDay && !$0.isMultiDay(calendar: calendar) && $0.overlaps(dayInterval) }
        let unsorted: [Item] = candidates.map { event in
            let start = max(0, event.startDate.timeIntervalSince(dayInterval.start) / 60)
            let end = min(dayLength, event.endDate.timeIntervalSince(dayInterval.start) / 60)
            return (event, start, max(end, start))
        }
        // Earlier first; for equal starts the longer event takes the left column.
        let items = unsorted.sorted { (a: Item, b: Item) -> Bool in
            if a.start != b.start { return a.start < b.start }
            if a.end != b.end { return a.end > b.end }
            return a.event.displayTitle < b.event.displayTitle
        }

        var result: [TimedEventLayout] = []
        var cluster: [(CalendarEvent, Double, Double, Int)] = []
        var columnEnds: [Double] = []
        var clusterEnd = -Double.infinity

        func flush() {
            for item in cluster {
                result.append(TimedEventLayout(event: item.0, startMinute: item.1, endMinute: item.2,
                                               column: item.3, columnCount: columnEnds.count))
            }
            cluster.removeAll()
            columnEnds.removeAll()
        }

        for (event, start, end) in items {
            let visualEnd = max(end, start + minimumMinutes)
            if start >= clusterEnd { flush() }
            let column = columnEnds.firstIndex { $0 <= start } ?? columnEnds.count
            if column == columnEnds.count { columnEnds.append(visualEnd) } else { columnEnds[column] = visualEnd }
            cluster.append((event, start, end, column))
            clusterEnd = max(clusterEnd, visualEnd)
        }
        flush()
        return result
    }

    /// Assigns lanes to all-day and multi-day events across a row of consecutive days.
    public static func layoutSpanningEvents(_ events: [CalendarEvent], days: [Date],
                                            calendar: Calendar) -> [SpanningEventLayout] {
        guard let first = days.first, let last = days.last else { return [] }
        let rowInterval = DateInterval(start: calendar.startOfDay(for: first),
                                       end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: last))!)
        let candidates = events
            .filter { ($0.isAllDay || $0.isMultiDay(calendar: calendar)) && $0.overlaps(rowInterval) }
            .sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                if $0.endDate != $1.endDate { return $0.endDate > $1.endDate }
                return $0.displayTitle < $1.displayTitle
            }

        var laneEnds: [Int] = []  // last occupied day index per lane
        var result: [SpanningEventLayout] = []
        for event in candidates {
            let indices = days.indices.filter { event.overlaps(calendar.dateInterval(of: .day, for: days[$0])!) }
            guard let firstIndex = indices.first, let lastIndex = indices.last else { continue }
            let lane = laneEnds.firstIndex { $0 < firstIndex } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(lastIndex) } else { laneEnds[lane] = lastIndex }
            result.append(SpanningEventLayout(event: event, firstIndex: firstIndex, lastIndex: lastIndex, lane: lane,
                                              continuesBefore: event.startDate < rowInterval.start,
                                              continuesAfter: event.endDate > rowInterval.end))
        }
        return result
    }

    /// Lines to draw in one month-view cell given how many lines fit (`capacity`).
    /// Spanning bars keep the same lane across the week; overflow collapses into `.more(n)`.
    public static func monthCellSlots(dayIndex: Int, spanning: [SpanningEventLayout],
                                      timed: [CalendarEvent], capacity: Int) -> [MonthCellSlot] {
        guard capacity > 0 else { return [] }
        let laneCount = (spanning.map(\.lane).max() ?? -1) + 1
        let barsToday = spanning.filter { $0.firstIndex <= dayIndex && dayIndex <= $0.lastIndex }
        let total = laneCount + timed.count
        let lineBudget = total <= capacity ? capacity : capacity - 1

        var slots: [MonthCellSlot] = []
        var shownBars = 0
        for lane in 0..<min(laneCount, lineBudget) {
            if let bar = barsToday.first(where: { $0.lane == lane }) {
                let isFirst = dayIndex == bar.firstIndex
                slots.append(.bar(bar, showsTitle: isFirst, isFirstSegment: isFirst && !bar.continuesBefore,
                                  isLastSegment: dayIndex == bar.lastIndex && !bar.continuesAfter))
                shownBars += 1
            } else {
                slots.append(.empty)
            }
        }
        let timedRoom = max(0, lineBudget - slots.count)
        let shownTimed = Array(timed.prefix(timedRoom))
        slots += shownTimed.map { .timed($0) }

        let hidden = (barsToday.count - shownBars) + (timed.count - shownTimed.count)
        if hidden > 0 { slots.append(.more(hidden)) }
        // Trailing empty lanes carry no information.
        while case .empty? = slots.last { slots.removeLast() }
        return slots
    }
}
