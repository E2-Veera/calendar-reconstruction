import CalendarCore
import SwiftUI

/// Event form: title, location, all-day, start/end, calendar, notes. Calendar.app edits in a
/// popover inspector; this reconstruction uses a sheet (documented as an approximation).
struct EventEditorView: View {
    let controller: CalendarController

    var body: some View {
        if let draft = controller.draft {
            let calendar = controller.calendar
            let components: DatePickerComponents = draft.isAllDay ? [.date] : [.date, .hourAndMinute]
            VStack(alignment: .leading, spacing: 12) {
                Text(draft.isNew ? "New Event" : "Edit Event").font(.headline)
                TextField("Title", text: binding(\.title, default: ""))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 15))
                    .accessibilityLabel("Title")
                TextField("Add Location", text: binding(\.location, default: ""))
                    .accessibilityLabel("Location")
                Divider()
                Form {
                    Toggle("all-day:", isOn: Binding(get: { controller.draft?.isAllDay ?? false },
                                                     set: { controller.draft?.setAllDay($0, calendar: calendar) }))
                    DatePicker("starts:", selection: Binding(get: { controller.draft?.start ?? Date() },
                                                             set: { controller.draft?.setStart($0) }),
                               displayedComponents: components)
                    DatePicker("ends:", selection: Binding(get: { controller.draft?.end ?? Date() },
                                                           set: { controller.draft?.setEnd($0) }),
                               displayedComponents: components)
                    Picker("calendar:", selection: binding(\.calendarID, default: controller.defaultCalendarID)) {
                        ForEach(controller.store.calendars) { info in
                            Text(info.name).tag(info.id)
                        }
                    }
                }
                Text("Notes").font(.system(size: 11)).foregroundStyle(.secondary)
                TextEditor(text: binding(\.notes, default: ""))
                    .font(.system(size: 13))
                    .frame(height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3)))
                    .accessibilityLabel("Notes")
                if let message = controller.draftError ?? draft.validationError?.errorDescription {
                    Text(message).foregroundStyle(.red).font(.system(size: 12))
                }
                HStack {
                    if !draft.isNew {
                        Button("Delete Event", role: .destructive) { controller.deleteEvent(draft.id) }
                    }
                    Spacer()
                    Button("Cancel") { controller.cancelDraft() }
                        .keyboardShortcut(.cancelAction)
                    Button(draft.isNew ? "Add" : "Save") { controller.commitDraft() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(draft.validationError != nil)
                }
            }
            .padding(20)
            .frame(width: 440)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<EventDraft, Value>, default fallback: Value) -> Binding<Value> {
        Binding(get: { controller.draft?[keyPath: keyPath] ?? fallback },
                set: { controller.draft?[keyPath: keyPath] = $0 })
    }
}
