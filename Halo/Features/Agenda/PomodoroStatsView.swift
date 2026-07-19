import Charts
import SwiftUI

/// Seven days of focus time as a bar chart, with today's numbers and the
/// streak. Swift Charts, local data only.
struct PomodoroStatsView: View {
    let history: PomodoroHistory
    let settings: SettingsStore
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 22, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text("Focus this week")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
            }

            Chart(history.lastSevenDays()) { record in
                BarMark(
                    x: .value("Day", record.day, unit: .day),
                    y: .value("Minutes", record.focusSeconds / 60)
                )
                .foregroundStyle(settings.accent.color.opacity(0.85))
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                        .foregroundStyle(.white.opacity(0.1))
                    AxisValueLabel()
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            Text(summary)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 10)
    }

    private var summary: String {
        var parts = [
            String(localized: "today \(history.todayMinutes) min"),
            String(localized: "\(history.todayRounds) rounds"),
        ]
        if history.streakDays > 1 {
            parts.append(String(localized: "\(history.streakDays) day streak"))
        }
        return parts.joined(separator: " · ")
    }
}
