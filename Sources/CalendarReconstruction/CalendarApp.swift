import AppKit
import CalendarCore
import SwiftUI

struct CalendarReconstructionApp: App {
    @State private var controller: CalendarController

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        let store = launchOptions.openStore()
        let savedMode = UserDefaults.standard.string(forKey: "lastViewMode").flatMap(CalendarViewMode.init(rawValue:))
        _controller = State(initialValue: CalendarController(store: store, mode: savedMode ?? .month))
    }

    var body: some Scene {
        Window("Calendar Reconstruction", id: "main") {
            ContentView(controller: controller)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear { NSApplication.shared.activate(ignoringOtherApps: true) }
                .onChange(of: controller.mode) { _, mode in
                    UserDefaults.standard.set(mode.rawValue, forKey: "lastViewMode")
                }
        }
        .defaultSize(width: 1280, height: 820)
        .commands { CalendarCommands(controller: controller) }
    }
}

/// Menu items and shortcuts recovered from Calendar.app's MainMenu.nib
/// (evidence/rea/mainmenu-resolved.md).
struct CalendarCommands: Commands {
    let controller: CalendarController

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Event") { controller.beginNewEvent() }
                .keyboardShortcut("n", modifiers: .command)
            Button("New Calendar…") { NotificationCenter.default.post(name: .newCalendarRequested, object: nil) }
                .keyboardShortcut("n", modifiers: [.command, .option])
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Edit Event") { controller.beginEditing() }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(controller.selectedEventID == nil)
            Button("Delete Event") { controller.deleteSelectedEvent() }
                .disabled(controller.selectedEventID == nil)
            Divider()
            Button("Find") { NotificationCenter.default.post(name: .findRequested, object: nil) }
                .keyboardShortcut("f", modifiers: .command)
        }
        CommandGroup(before: .toolbar) {
            Button("By Day") { controller.setMode(.day) }.keyboardShortcut("1", modifiers: .command)
            Button("By Week") { controller.setMode(.week) }.keyboardShortcut("2", modifiers: .command)
            Button("By Month") { controller.setMode(.month) }.keyboardShortcut("3", modifiers: .command)
            Button("By Year") { controller.setMode(.year) }.keyboardShortcut("4", modifiers: .command)
            Divider()
            Button("Previous") { controller.goPrevious() }.keyboardShortcut(.leftArrow, modifiers: .command)
            Button("Next") { controller.goNext() }.keyboardShortcut(.rightArrow, modifiers: .command)
            Button("Go to Today") { controller.goToToday() }.keyboardShortcut("t", modifiers: .command)
            Button("Go to Date…") { NotificationCenter.default.post(name: .goToDateRequested, object: nil) }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
        }
    }
}

extension Notification.Name {
    static let newCalendarRequested = Notification.Name("CalendarReconstruction.newCalendarRequested")
    static let findRequested = Notification.Name("CalendarReconstruction.findRequested")
    static let goToDateRequested = Notification.Name("CalendarReconstruction.goToDateRequested")
}
