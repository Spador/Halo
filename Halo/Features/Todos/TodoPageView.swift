import SwiftUI

/// The to-do card: quick-add field on top, incomplete reminders below.
/// Click the circle to complete one — it completes in Apple Reminders,
/// this is the real database, not a copy.
struct TodoPageView: View {
    let todos: RemindersService
    let settings: SettingsStore

    @State private var draft = ""

    var body: some View {
        switch todos.authState {
        case .notDetermined:
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
                Button("Connect Reminders") { todos.connect() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.15)))
                Text("Reminders never leave this Mac.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }

        case .denied:
            Text("Reminders access denied — enable it in System Settings › Privacy & Security › Reminders.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

        case .authorized:
            VStack(spacing: 8) {
                addField
                if todos.items.isEmpty {
                    Text("All clear")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 1) {
                            ForEach(todos.items) { item in
                                row(item)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
    }

    private var addField: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            TextField("Add a reminder", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .onSubmit {
                    todos.add(draft)
                    draft = ""
                }
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .background(Capsule().fill(.white.opacity(0.1)))
    }

    private func row(_ item: TodoItem) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    todos.complete(item)
                }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(settings.accent.color.opacity(0.8))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Complete")

            Text(item.title)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
            Spacer(minLength: 8)
            if let due = item.due {
                Text(due, format: dueFormat(due))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(
                        item.isOverdue ? AnyShapeStyle(Color.red.opacity(0.85))
                            : AnyShapeStyle(.white.opacity(0.4))
                    )
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 26)
    }

    /// Today's items show just the time; anything else shows the date.
    private func dueFormat(_ due: Date) -> Date.FormatStyle {
        Foundation.Calendar.current.isDateInToday(due)
            ? .dateTime.hour().minute()
            : .dateTime.day().month()
    }
}
