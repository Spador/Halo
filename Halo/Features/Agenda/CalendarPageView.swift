import SwiftUI

/// Full calendar page: month grid on the left (with ‹ › navigation and
/// event dots), the selected day's events on the right.
struct CalendarPageView: View {
    let calendar: CalendarService

    @State private var displayedMonth = Date()
    @State private var selectedDay = Date()
    @State private var eventDays: Set<Int> = []
    @State private var dayEvents: [AgendaEvent] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        switch calendar.authState {
        case .notDetermined:
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
                Button("Connect Calendar") { calendar.connect() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.15)))
                Text("Events never leave this Mac.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
        case .denied:
            Text("Calendar access denied — enable it in System Settings › Privacy & Security › Calendars.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        case .authorized:
            HStack(alignment: .top, spacing: 18) {
                monthGrid.frame(width: 220)
                dayPanel.frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(.horizontal, 24)
            .onAppear { reloadMonth(); reloadDay() }
            .onChange(of: displayedMonth) { reloadMonth() }
            .onChange(of: selectedDay) { reloadDay() }
            .onChange(of: calendar.revision) { reloadMonth(); reloadDay() }
        }
    }

    // MARK: - Month grid

    private var monthGrid: some View {
        VStack(spacing: 6) {
            HStack {
                monthArrow("chevron.left", by: -1)
                Spacer()
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                monthArrow("chevron.right", by: 1)
            }

            HStack(spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 22)
                }
                ForEach(1...daysInMonth, id: \.self) { day in
                    dayCell(day)
                }
            }
        }
    }

    private func monthArrow(_ symbol: String, by months: Int) -> some View {
        Button {
            if let shifted = Foundation.Calendar.current.date(
                byAdding: .month, value: months, to: displayedMonth
            ) {
                displayedMonth = shifted
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 20, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayCell(_ day: Int) -> some View {
        let date = self.date(forDay: day)
        let cal = Foundation.Calendar.current
        let isSelected = cal.isDate(date, inSameDayAs: selectedDay)
        let isToday = cal.isDateInToday(date)

        return Button {
            selectedDay = date
        } label: {
            VStack(spacing: 1) {
                Text("\(day)")
                    .font(.system(size: 10, weight: isToday ? .bold : .regular).monospacedDigit())
                    .foregroundStyle(
                        isSelected ? .black : isToday ? .white : .white.opacity(0.75)
                    )
                Circle()
                    .fill(eventDays.contains(day)
                        ? (isSelected ? Color.black : .white.opacity(0.7))
                        : .clear)
                    .frame(width: 3, height: 3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isSelected ? .white : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day events panel

    private var dayPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selectedDay, format: .dateTime.weekday(.wide).month().day())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
            if dayEvents.isEmpty {
                Text("No events")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(dayEvents) { event in
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(event.isAllDay
                                    ? "all-day"
                                    : event.start.formatted(.dateTime.hour().minute()))
                                    .font(.system(size: 9, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(.white.opacity(0.5))
                                    .frame(width: 42, alignment: .leading)
                                Text(event.title)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.9))
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Date math

    private var firstOfMonth: Date {
        let cal = Foundation.Calendar.current
        let components = cal.dateComponents([.year, .month], from: displayedMonth)
        return cal.date(from: components) ?? displayedMonth
    }

    private var daysInMonth: Int {
        Foundation.Calendar.current.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30
    }

    /// Empty grid cells before day 1, honoring the user's first weekday.
    private var leadingBlanks: Int {
        let cal = Foundation.Calendar.current
        let weekday = cal.component(.weekday, from: firstOfMonth)
        return (weekday - cal.firstWeekday + 7) % 7
    }

    private var weekdaySymbols: [String] {
        let cal = Foundation.Calendar.current
        let symbols = cal.veryShortWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func date(forDay day: Int) -> Date {
        Foundation.Calendar.current.date(byAdding: .day, value: day - 1, to: firstOfMonth)
            ?? firstOfMonth
    }

    private func reloadMonth() {
        eventDays = calendar.daysWithEvents(inMonthOf: displayedMonth)
    }

    private func reloadDay() {
        dayEvents = calendar.events(on: selectedDay)
    }
}
