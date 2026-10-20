import CalendarCore
import SwiftUI

/// Calendar list (checkbox per calendar, tinted with its colour) and a mini month,
/// following Calendar.app's "Show Calendar List" sidebar.
struct SidebarView: View {
    let controller: CalendarController
    @State private var editingCalendar: CalendarInfo?
    @State private var creatingCalendar = false
    @State private var pendingDelete: CalendarInfo?
    @State private var miniMonth = Date()

    var body: some View {
        let store = controller.store
        VStack(spacing: 0) {
            List {
                Section("Calendars") {
                    ForEach(store.calendars) { info in
                        CalendarRow(info: info) { store.setCalendarVisible(id: info.id, !info.isVisible) }
                            .contextMenu {
                                Button("Get Info") { editingCalendar = info }
                                Button("Delete", role: .destructive) { pendingDelete = info }
                                    .disabled(store.calendars.count <= 1)
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            HStack {
                Button { creatingCalendar = true } label: { Image(systemName: "plus") }
                    .buttonStyle(.borderless)
                    .help("New Calendar (⌥⌘N)")
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            Divider()
            VStack(spacing: 6) {
                HStack {
                    Spacer()
                    Button { miniMonth = controller.math.step(miniMonth, mode: .month, by: -1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    Button { miniMonth = controller.math.step(miniMonth, mode: .month, by: 1) } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .buttonStyle(.borderless)
                MiniMonthView(controller: controller, month: miniMonth, selectedDay: controller.selectedDay) {
                    controller.go(to: $0)
                }
            }
            .padding(12)
        }
        .onAppear { miniMonth = controller.displayedDate }
        .onChange(of: controller.displayedDate) { _, date in miniMonth = date }
        .onReceive(NotificationCenter.default.publisher(for: .newCalendarRequested)) { _ in creatingCalendar = true }
        .sheet(isPresented: $creatingCalendar) {
            CalendarEditorSheet(title: "New Calendar", info: nil) { name, hex in
                store.addCalendar(name: name, colorHex: hex)
            }
        }
        .sheet(item: $editingCalendar) { info in
            CalendarEditorSheet(title: "Calendar Info", info: info) { name, hex in
                var updated = info
                updated.name = name
                updated.colorHex = hex
                store.updateCalendar(updated)
            }
        }
        .confirmationDialog("Delete the calendar “\(pendingDelete?.name ?? "")”?",
                            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let info = pendingDelete { try? store.deleteCalendar(id: info.id) }
                pendingDelete = nil
            }
        } message: {
            Text("All events in this calendar will also be deleted.")
        }
    }
}

struct CalendarRow: View {
    let info: CalendarInfo
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: info.isVisible ? "checkmark.square.fill" : "square")
                .foregroundStyle(Color(hex: info.colorHex))
                .font(.system(size: 14))
                .onTapGesture(perform: toggle)
                .accessibilityLabel(info.isVisible ? "Hide \(info.name)" : "Show \(info.name)")
                .accessibilityAddTraits(.isButton)
            Text(info.name)
        }
    }
}

struct CalendarEditorSheet: View {
    let title: String
    let info: CalendarInfo?
    let save: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = CalendarPalette.colors[4].hex

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            TextField("Name", text: $name)
            HStack(spacing: 10) {
                ForEach(CalendarPalette.colors, id: \.hex) { entry in
                    Circle()
                        .fill(Color(hex: entry.hex))
                        .frame(width: 22, height: 22)
                        .overlay { if entry.hex == colorHex { Circle().stroke(.primary, lineWidth: 2).padding(-3) } }
                        .onTapGesture { colorHex = entry.hex }
                        .help(entry.name)
                        .accessibilityLabel(entry.name)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("OK") {
                    save(name, colorHex)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            name = info?.name ?? "Untitled"
            colorHex = info?.colorHex ?? colorHex
        }
    }
}
