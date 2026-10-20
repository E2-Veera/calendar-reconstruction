import AppKit
import CalendarCore
import SwiftUI

/// Command-line modes that operate on the same store file as the GUI, then exit.
/// They let tests verify persistence across separate processes (= application restarts).
@MainActor
enum HeadlessRunner {
    static let usage = """
    Usage: CalendarReconstruction [--store PATH] [--reset] [command]

    With no command the app window opens. Commands:
      --list-events                       Print all events as JSON
      --add-event TITLE --start T --end T [--all-day] [--calendar NAME] [--location L] [--notes N]
                                          T = yyyy-MM-dd'T'HH:mm (local time) or yyyy-MM-dd for all-day
      --delete-event TITLE                Delete the first event with this exact title
      --search QUERY                      Print matching events and matched fields
      --render-screenshots DIR [--date yyyy-MM-dd]
                                          Render month/week/day/year/search views offscreen to PNG
    Options:
      --store PATH   Data file (default ~/Library/Application Support/CalendarReconstruction/calendar-store.json)
      --reset        Delete the data file first and re-seed the sample events
    """

    static func run(_ command: LaunchOptions.HeadlessCommand, options: LaunchOptions) -> Int32 {
        if command == .help {
            print(usage)
            return 0
        }
        let store = options.openStore()
        switch command {
        case .help:
            return 0
        case .listEvents:
            return listEvents(store)
        case .addEvent:
            return addEvent(store, options)
        case .deleteEvent:
            guard let title = options.arguments["--delete-event"],
                  let event = store.events.first(where: { $0.title == title }) else {
                fputs("No event titled that way.\n", stderr)
                return 1
            }
            store.deleteEvent(id: event.id)
            print("deleted \(event.id.uuidString)")
            return 0
        case .search:
            let query = options.arguments["--search"] ?? ""
            for result in store.search(query) {
                let fields = result.matchedFields.map { $0.tokenText(query) }.joined(separator: ", ")
                print("\(result.event.title)\t\(iso(result.event.startDate))\t\(fields)")
            }
            return 0
        case .renderScreenshots:
            return renderScreenshots(store, options)
        }
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .current
        return formatter.string(from: date)
    }

    private static func listEvents(_ store: EventStore) -> Int32 {
        let rows: [[String: Any]] = store.events.sorted(by: EventStore.displayOrder).map { event in
            [
                "id": event.id.uuidString, "title": event.title, "start": iso(event.startDate), "end": iso(event.endDate),
                "allDay": event.isAllDay, "location": event.location, "notes": event.notes,
                "calendar": store.calendar(id: event.calendarID)?.name ?? "",
            ]
        }
        let data = try! JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        return 0
    }

    static func parseDate(_ text: String) -> Date? {
        for format in ["yyyy-MM-dd'T'HH:mm", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = .current
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return ISO8601DateFormatter().date(from: text)
    }

    private static func addEvent(_ store: EventStore, _ options: LaunchOptions) -> Int32 {
        let args = options.arguments
        let allDay = options.flags.contains("--all-day")
        guard let title = args["--add-event"], let start = args["--start"].flatMap(parseDate) else {
            fputs(usage + "\n", stderr)
            return 2
        }
        let calendar = Calendar.current
        var end = args["--end"].flatMap(parseDate) ?? start.addingTimeInterval(3600)
        var startDate = start
        if allDay {
            // --end is the inclusive last day, as in the event form.
            startDate = calendar.startOfDay(for: start)
            end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: args["--end"] == nil ? start : end))!
        }
        let calendarID = args["--calendar"].flatMap { name in store.calendars.first { $0.name == name }?.id }
            ?? store.calendars[0].id
        do {
            let event = try store.addEvent(CalendarEvent(calendarID: calendarID, title: title, startDate: startDate,
                                                         endDate: end, isAllDay: allDay,
                                                         location: args["--location"] ?? "", notes: args["--notes"] ?? ""))
            print("added \(event.id.uuidString)")
            return 0
        } catch {
            fputs("error: \((error as? LocalizedError)?.errorDescription ?? "\(error)")\n", stderr)
            return 1
        }
    }

    // MARK: Offscreen rendering

    private static func renderScreenshots(_ store: EventStore, _ options: LaunchOptions) -> Int32 {
        _ = NSApplication.shared
        let directory = URL(fileURLWithPath: (options.arguments["--render-screenshots"]! as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let anchor = options.arguments["--date"].flatMap(parseDate) ?? Date()

        var scenarios: [(String, CalendarViewMode, String, Bool)] = CalendarViewMode.allCases.map {
            ("reconstruction-\($0.rawValue)", $0, "", true)
        }
        scenarios.append(("reconstruction-search", .month, "review", true))
        scenarios.append(("reconstruction-month-dark", .month, "", false))

        for (name, mode, query, light) in scenarios {
            let controller = CalendarController(store: store, mode: mode)
            controller.go(to: anchor)
            controller.searchText = query
            if mode == .day {
                controller.selectedEventID = controller.events(on: anchor).first { !$0.isAllDay }?.id
            }
            let view = StaticWindow(controller: controller)
                .frame(width: 1280, height: 800)
                .environment(\.isStaticRender, true)
                .environment(\.colorScheme, light ? .light : .dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
                fputs("failed to render \(name)\n", stderr)
                return 1
            }
            let url = directory.appendingPathComponent("\(name).png")
            do { try png.write(to: url) } catch {
                fputs("failed to write \(url.path): \(error)\n", stderr)
                return 1
            }
            print(url.path)
        }
        return 0
    }
}

/// Window-like composition drawable by ImageRenderer (no NSSplitView/NSTableView/toolbar).
private struct StaticWindow: View {
    let controller: CalendarController
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar stand-in
            HStack(spacing: 14) {
                HStack(spacing: 7) { ForEach([Color.red, .yellow, .green], id: \.self) { Circle().fill($0).frame(width: 12) } }
                Image(systemName: "plus").font(.system(size: 14))
                Spacer()
                HStack(spacing: 0) {
                    ForEach(CalendarViewMode.allCases) { mode in
                        Text(mode.label).font(.system(size: 12))
                            .padding(.horizontal, 14).padding(.vertical, 3)
                            .background(mode == controller.mode ? Color.gray.opacity(0.3) : .clear,
                                        in: RoundedRectangle(cornerRadius: 5))
                    }
                }
                .padding(2)
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 7))
                Spacer()
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(controller.searchText.isEmpty ? "Search" : controller.searchText)
                        .foregroundStyle(controller.searchText.isEmpty ? .secondary : .primary)
                    Spacer()
                }
                .font(.system(size: 12))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .frame(width: 200)
                .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color(nsColor: .windowBackgroundColor))
            Divider()
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Calendars").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    ForEach(controller.store.calendars) { info in
                        HStack(spacing: 6) {
                            Image(systemName: info.isVisible ? "checkmark.square.fill" : "square")
                                .foregroundStyle(Color(hex: info.colorHex))
                            Text(info.name).font(.system(size: 13))
                        }
                    }
                    Spacer()
                    MiniMonthView(controller: controller, month: controller.displayedDate,
                                  selectedDay: controller.selectedDay) { _ in }
                }
                .padding(14)
                .frame(width: 220)
                .background(Color(nsColor: .windowBackgroundColor).opacity(colorScheme == .dark ? 1 : 0.6))
                Divider()
                CalendarArea(controller: controller)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
