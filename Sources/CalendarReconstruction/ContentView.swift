import CalendarCore
import SwiftUI

/// True when views are rendered offscreen by `--render-screenshots`; AppKit-backed controls
/// (buttons, scroll views, lists) are replaced by plain drawings that ImageRenderer can draw.
private struct StaticRenderKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isStaticRender: Bool {
        get { self[StaticRenderKey.self] }
        set { self[StaticRenderKey.self] = newValue }
    }
}

extension CalendarController {
    func color(for event: CalendarEvent) -> Color {
        Color(hex: store.calendar(id: event.calendarID)?.colorHex ?? "#8E8E93")
    }

    func timeRange(_ event: CalendarEvent) -> String {
        event.isAllDay ? "all-day" : "\(math.timeString(event.startDate)) – \(math.timeString(event.endDate))"
    }
}

struct ContentView: View {
    @Bindable var controller: CalendarController
    @State private var showingGoToDate = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationSplitView {
            SidebarView(controller: controller)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 320)
        } detail: {
            CalendarArea(controller: controller)
                .focusable()
                .focusEffectDisabled()
                .onDeleteCommand { controller.deleteSelectedEvent() }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button { controller.beginNewEvent() } label: { Label("New Event", systemImage: "plus") }
                    .help("Create a new event (⌘N)")
            }
            ToolbarItem(placement: .principal) {
                Picker("View", selection: Binding(get: { controller.mode }, set: { controller.setMode($0) })) {
                    ForEach(CalendarViewMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("calendar view switcher")
                .frame(width: 260)
            }
        }
        .searchable(text: $controller.searchText, placement: .toolbar, prompt: "Search")
        .modifier(SearchFocusModifier(focused: $searchFocused))
        .onReceive(NotificationCenter.default.publisher(for: .findRequested)) { _ in searchFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: .goToDateRequested)) { _ in showingGoToDate = true }
        .sheet(item: $controller.draft) { _ in EventEditorView(controller: controller) }
        .sheet(isPresented: $showingGoToDate) { GoToDateSheet(controller: controller) }
        .overlay(alignment: .bottom) {
            if let error = controller.store.lastError {
                Text(error)
                    .padding(8)
                    .background(.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
                    .padding()
            }
        }
    }
}

/// `searchFocused` exists from macOS 15; on 14 ⌘F falls back to the system behaviour.
private struct SearchFocusModifier: ViewModifier {
    var focused: FocusState<Bool>.Binding
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.searchFocused(focused)
        } else {
            content
        }
    }
}

/// Header + active view + optional search-results column. Shared by the window and the
/// offscreen screenshot renderer.
struct CalendarArea: View {
    let controller: CalendarController

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HeaderBar(controller: controller)
                Rectangle().fill(Theme.monthTopDivider).frame(height: 1)
                switch controller.mode {
                case .day: DayView(controller: controller)
                case .week: TimeGridView(controller: controller, days: controller.math.weekDays(containing: controller.displayedDate))
                case .month: MonthView(controller: controller)
                case .year: YearView(controller: controller)
                }
            }
            if controller.isSearching {
                Divider()
                SearchResultsView(controller: controller).frame(width: 300)
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct HeaderBar: View {
    let controller: CalendarController
    @Environment(\.isStaticRender) private var isStaticRender

    var body: some View {
        let title = controller.headerTitle
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                (Text(title.bold).fontWeight(.bold) + Text(title.regular.isEmpty ? "" : " " + title.regular))
                    .font(.system(size: 26))
                if controller.mode == .day {
                    Text(controller.math.formatted(controller.displayedDate, template: "EEEE"))
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isStaticRender {
                HStack(spacing: 1) {
                    ForEach(["‹", "Today", "›"], id: \.self) { label in
                        Text(label).font(.system(size: 13)).padding(.horizontal, 9).padding(.vertical, 3)
                            .background(Color.gray.opacity(0.15))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                ControlGroup {
                    Button { controller.goPrevious() } label: { Image(systemName: "chevron.left") }
                        .help("Previous (⌘←)")
                    Button("Today") { controller.goToToday() }
                        .help("Go to Today (⌘T)")
                    Button { controller.goNext() } label: { Image(systemName: "chevron.right") }
                        .help("Next (⌘→)")
                }
                .fixedSize()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
}

struct SearchResultsView: View {
    let controller: CalendarController
    @Environment(\.isStaticRender) private var isStaticRender

    var body: some View {
        let results = controller.searchResults
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Search Results").font(.headline)
                Spacer()
                Text("\(results.count)").foregroundStyle(.secondary)
            }
            .padding(10)
            Divider()
            if results.isEmpty {
                Text("No Events").foregroundStyle(.secondary).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isStaticRender {
                VStack(spacing: 0) { rows(results) }
                Spacer(minLength: 0)
            } else {
                ScrollView { LazyVStack(spacing: 0) { rows(results) } }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func rows(_ results: [SearchResult]) -> some View {
        let query = controller.searchText.trimmingCharacters(in: .whitespaces)
        ForEach(results) { result in
            let event = result.event
            let selected = controller.selectedEventID == event.id
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(controller.color(for: event)).frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.displayTitle).font(.system(size: 13, weight: .semibold))
                    Text("\(controller.math.formatted(event.startDate, template: "EEEdMMMy"))  \(controller.timeRange(event))")
                        .font(.system(size: 11))
                    if !event.location.isEmpty {
                        Text(event.location).font(.system(size: 11)).foregroundStyle(selected ? .white : .secondary)
                    }
                    Text(result.matchedFields.map { $0.tokenText(query) }.joined(separator: ", "))
                        .font(.system(size: 10))
                        .foregroundStyle(selected ? .white : .secondary)
                }
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(selected ? .white : .primary)
            .background(selected ? Color.accentColor : .clear)
            .contentShape(Rectangle())
            .onTapGesture { controller.reveal(event.id) }
            .onTapGesture(count: 2) { controller.beginEditing(event.id) }
            Divider()
        }
    }
}

struct GoToDateSheet: View {
    let controller: CalendarController
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Go to Date").font(.headline)
            DatePicker("Date:", selection: $date, displayedComponents: .date)
                .datePickerStyle(.field)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Show") {
                    controller.go(to: date)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear { date = controller.displayedDate }
    }
}
