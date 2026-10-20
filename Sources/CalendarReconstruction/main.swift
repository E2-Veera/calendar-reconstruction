import AppKit
import CalendarCore
import Foundation

/// Command-line options. GUI launches accept `--store` and `--reset`; the remaining flags run
/// headless commands (used by the automated tests and the demo) and exit without a window.
struct LaunchOptions {
    var storeURL: URL = EventStore.defaultFileURL
    var reset = false
    var headless: HeadlessCommand?
    var arguments: [String: String] = [:]
    var flags: Set<String> = []

    enum HeadlessCommand: String {
        case listEvents = "--list-events"
        case addEvent = "--add-event"
        case deleteEvent = "--delete-event"
        case search = "--search"
        case renderScreenshots = "--render-screenshots"
        case help = "--help"
    }

    static let valueOptions: Set<String> = ["--store", "--title", "--start", "--end", "--calendar", "--location",
                                            "--notes", "--search", "--render-screenshots", "--date", "--add-event",
                                            "--delete-event"]

    static func parse(_ args: [String]) -> LaunchOptions {
        var options = LaunchOptions()
        var index = 1
        while index < args.count {
            let arg = args[index]
            if valueOptions.contains(arg), index + 1 < args.count {
                options.arguments[arg] = args[index + 1]
                index += 2
            } else {
                options.flags.insert(arg)
                index += 1
            }
            if let command = HeadlessCommand(rawValue: arg) { options.headless = command }
        }
        if let path = options.arguments["--store"] {
            options.storeURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        options.reset = options.flags.contains("--reset")
        return options
    }

    /// Opens the store, deleting it first when `--reset` was passed (re-seeds sample data).
    func openStore() -> EventStore {
        if reset { try? FileManager.default.removeItem(at: storeURL) }
        return EventStore(fileURL: storeURL)
    }
}

let launchOptions = LaunchOptions.parse(CommandLine.arguments)

if let command = launchOptions.headless {
    exit(MainActor.assumeIsolated { HeadlessRunner.run(command, options: launchOptions) })
}

CalendarReconstructionApp.main()
