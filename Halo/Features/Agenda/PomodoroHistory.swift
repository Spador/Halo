import Foundation
import Observation

/// Local-only Pomodoro history: focus seconds and completed rounds per
/// day, kept in the app preferences for sixty days. Nothing ever leaves
/// the machine; this exists purely to draw the stats view.
@Observable
final class PomodoroHistory {
    struct DayRecord: Codable, Equatable, Identifiable {
        var day: Date
        var focusSeconds: Int
        var completedRounds: Int

        var id: Date { day }
    }

    private(set) var records: [DayRecord] = []

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "pomodoro.history"
    private static let keepDays = 60

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([DayRecord].self, from: data) {
            records = saved
        }
    }

    /// Called by the engine whenever a focus phase ends, however it ends:
    /// natural completions count as a round, partial ones only add time.
    func record(focusSeconds: Int, completedRound: Bool) {
        guard focusSeconds > 0 || completedRound else { return }
        let today = Foundation.Calendar.current.startOfDay(for: Date())
        if let index = records.firstIndex(where: { $0.day == today }) {
            records[index].focusSeconds += focusSeconds
            records[index].completedRounds += completedRound ? 1 : 0
        } else {
            records.append(
                DayRecord(
                    day: today,
                    focusSeconds: focusSeconds,
                    completedRounds: completedRound ? 1 : 0
                )
            )
        }
        prune()
        persist()
    }

    var todayMinutes: Int {
        let today = Foundation.Calendar.current.startOfDay(for: Date())
        return (records.first { $0.day == today }?.focusSeconds ?? 0) / 60
    }

    var todayRounds: Int {
        let today = Foundation.Calendar.current.startOfDay(for: Date())
        return records.first { $0.day == today }?.completedRounds ?? 0
    }

    /// The last seven days oldest-first, zero-filled so the chart always
    /// shows a full week.
    func lastSevenDays() -> [DayRecord] {
        let calendar = Foundation.Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today)
            else { return nil }
            return records.first { $0.day == day }
                ?? DayRecord(day: day, focusSeconds: 0, completedRounds: 0)
        }
    }

    /// Consecutive days with any focus time, ending today (or yesterday,
    /// so an unstarted morning doesn't read as a broken streak).
    var streakDays: Int {
        let calendar = Foundation.Calendar.current
        var day = calendar.startOfDay(for: Date())
        var streak = 0
        if !records.contains(where: { $0.day == day && $0.focusSeconds > 0 }) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day)
            else { return 0 }
            day = yesterday
        }
        while records.contains(where: { $0.day == day && $0.focusSeconds > 0 }) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day)
            else { break }
            day = previous
        }
        return streak
    }

    private func prune() {
        let calendar = Foundation.Calendar.current
        guard let cutoff = calendar.date(
            byAdding: .day, value: -Self.keepDays, to: calendar.startOfDay(for: Date())
        ) else { return }
        records.removeAll { $0.day < cutoff }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
