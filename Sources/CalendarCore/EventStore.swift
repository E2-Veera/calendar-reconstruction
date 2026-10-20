import Foundation
import Observation

public enum StoreError: Error, Equatable, LocalizedError {
    case endBeforeStart
    case unknownCalendar
    case unknownEvent
    case cannotDeleteLastCalendar

    public var errorDescription: String? {
        switch self {
        case .endBeforeStart: "The event’s end time must be after its start time."
        case .unknownCalendar: "The selected calendar no longer exists."
        case .unknownEvent: "The event no longer exists."
        case .cannotDeleteLastCalendar: "You need at least one calendar."
        }
    }
}

/// Field that matched a search query. Mirrors Calendar.app's search tokens
/// ("Title contains “%@”", "Location contains “%@”", "Notes contain “%@”").
public enum SearchField: String, CaseIterable, Sendable {
    case title, location, notes

    public func tokenText(_ query: String) -> String {
        switch self {
        case .title: "Title contains “\(query)”"
        case .location: "Location contains “\(query)”"
        case .notes: "Notes contain “\(query)”"
        }
    }
}

public struct SearchResult: Identifiable, Equatable, Sendable {
    public var id: UUID { event.id }
    public let event: CalendarEvent
    public let matchedFields: [SearchField]
}

/// On-disk document. Versioned so the format can evolve.
struct StoreDocument: Codable {
    var version: Int = 1
    var calendars: [CalendarInfo]
    var events: [CalendarEvent]
}

/// Holds calendars and events and persists every change to a JSON file.
@Observable
public final class EventStore {
    public private(set) var calendars: [CalendarInfo] = []
    public private(set) var events: [CalendarEvent] = []
    /// nil = in-memory only (unit tests).
    public let fileURL: URL?
    /// Last persistence problem, surfaced in the UI rather than crashing.
    public private(set) var lastError: String?
    /// Set when an unreadable store file was moved aside on load.
    public private(set) var recoveredCorruptFile: URL?

    public static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CalendarReconstruction", isDirectory: true)
            .appendingPathComponent("calendar-store.json")
    }

    /// Loads `fileURL` if it exists; otherwise seeds sample data (when requested) and saves it.
    public init(fileURL: URL?, seedSampleData: Bool = true, calendar: Calendar = .current, now: Date = Date()) {
        self.fileURL = fileURL
        if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let document = try Self.decoder.decode(StoreDocument.self, from: Data(contentsOf: fileURL))
                calendars = document.calendars
                events = document.events
                return
            } catch {
                let aside = fileURL.deletingPathExtension()
                    .appendingPathExtension("corrupt-\(Int(now.timeIntervalSince1970)).json")
                try? FileManager.default.moveItem(at: fileURL, to: aside)
                recoveredCorruptFile = aside
                lastError = "The calendar data file couldn’t be read and was moved to \(aside.lastPathComponent)."
            }
        }
        if seedSampleData {
            let sample = SampleData.make(now: now, calendar: calendar)
            calendars = sample.calendars
            events = sample.events
        } else {
            calendars = [CalendarInfo(name: "Calendar", colorHex: "#1BADF8")]
        }
        persist()
    }

    // MARK: Persistence

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private func persist() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let data = try Self.encoder.encode(StoreDocument(calendars: calendars, events: events))
            try data.write(to: fileURL, options: .atomic)
            if recoveredCorruptFile == nil { lastError = nil }
        } catch {
            lastError = "Couldn’t save calendar data: \(error.localizedDescription)"
        }
    }

    // MARK: Lookup

    public func calendar(id: UUID) -> CalendarInfo? { calendars.first { $0.id == id } }
    public func event(id: UUID) -> CalendarEvent? { events.first { $0.id == id } }
    public var visibleCalendarIDs: Set<UUID> { Set(calendars.filter(\.isVisible).map(\.id)) }

    /// Events overlapping `interval`, all-day first, then by start time.
    public func events(in interval: DateInterval, visibleOnly: Bool = true) -> [CalendarEvent] {
        let visible = visibleCalendarIDs
        return events
            .filter { (!visibleOnly || visible.contains($0.calendarID)) && $0.overlaps(interval) }
            .sorted(by: Self.displayOrder)
    }

    public static func displayOrder(_ a: CalendarEvent, _ b: CalendarEvent) -> Bool {
        if a.isAllDay != b.isAllDay { return a.isAllDay }
        if a.startDate != b.startDate { return a.startDate < b.startDate }
        if a.endDate != b.endDate { return a.endDate < b.endDate }
        return a.displayTitle.localizedStandardCompare(b.displayTitle) == .orderedAscending
    }

    // MARK: Event CRUD

    private func validate(_ event: CalendarEvent) throws {
        guard calendar(id: event.calendarID) != nil else { throw StoreError.unknownCalendar }
        guard event.endDate >= event.startDate else { throw StoreError.endBeforeStart }
    }

    @discardableResult
    public func addEvent(_ event: CalendarEvent) throws -> CalendarEvent {
        try validate(event)
        events.append(event)
        persist()
        return event
    }

    public func updateEvent(_ event: CalendarEvent) throws {
        try validate(event)
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { throw StoreError.unknownEvent }
        events[index] = event
        persist()
    }

    public func deleteEvent(id: UUID) {
        events.removeAll { $0.id == id }
        persist()
    }

    // MARK: Calendar CRUD

    @discardableResult
    public func addCalendar(name: String, colorHex: String) -> CalendarInfo {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let info = CalendarInfo(name: trimmed.isEmpty ? "Untitled" : trimmed, colorHex: colorHex)
        calendars.append(info)
        persist()
        return info
    }

    public func updateCalendar(_ info: CalendarInfo) {
        guard let index = calendars.firstIndex(where: { $0.id == info.id }) else { return }
        calendars[index] = info
        persist()
    }

    public func setCalendarVisible(id: UUID, _ visible: Bool) {
        guard let index = calendars.firstIndex(where: { $0.id == id }) else { return }
        calendars[index].isVisible = visible
        persist()
    }

    /// Deletes a calendar and all of its events.
    public func deleteCalendar(id: UUID) throws {
        guard calendars.count > 1 else { throw StoreError.cannotDeleteLastCalendar }
        calendars.removeAll { $0.id == id }
        events.removeAll { $0.calendarID == id }
        persist()
    }

    // MARK: Search

    /// Case- and diacritic-insensitive search across title, location and notes. Every
    /// whitespace-separated term must match at least one field. Results are chronological.
    public func search(_ query: String, visibleOnly: Bool = false) -> [SearchResult] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return [] }
        let visible = visibleCalendarIDs
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        return events
            .filter { !visibleOnly || visible.contains($0.calendarID) }
            .compactMap { event -> SearchResult? in
                let fields: [(SearchField, String)] = [(.title, event.title), (.location, event.location), (.notes, event.notes)]
                var matched = Set<SearchField>()
                for term in terms {
                    let hits = fields.filter { $0.1.range(of: term, options: options) != nil }.map(\.0)
                    if hits.isEmpty { return nil }
                    matched.formUnion(hits)
                }
                return SearchResult(event: event, matchedFields: SearchField.allCases.filter(matched.contains))
            }
            .sorted { a, b in
                a.event.startDate != b.event.startDate ? a.event.startDate < b.event.startDate
                    : Self.displayOrder(a.event, b.event)
            }
    }
}
