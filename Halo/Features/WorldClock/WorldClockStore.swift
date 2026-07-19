import Foundation
import Observation

/// The user's world clock cities: a persisted list of time zone
/// identifiers, nothing more. All display math happens in the view.
@Observable
final class WorldClockStore {
    struct Entry: Identifiable, Equatable {
        let identifier: String

        var id: String { identifier }
        var timeZone: TimeZone? { TimeZone(identifier: identifier) }

        /// "Asia/Kolkata" reads as "Kolkata".
        var cityName: String {
            identifier.split(separator: "/").last
                .map { $0.replacingOccurrences(of: "_", with: " ") }
                ?? identifier
        }
    }

    private(set) var entries: [Entry]

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "worldClock.zones"
    private static let starterZones = [
        "America/New_York", "Europe/London", "Asia/Kolkata", "Asia/Tokyo",
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let identifiers = defaults.stringArray(forKey: Self.key) ?? Self.starterZones
        entries = identifiers
            .filter { TimeZone(identifier: $0) != nil }
            .map(Entry.init)
    }

    func add(_ identifier: String) {
        guard TimeZone(identifier: identifier) != nil,
              !entries.contains(where: { $0.identifier == identifier })
        else { return }
        entries.append(Entry(identifier: identifier))
        persist()
    }

    func remove(_ entry: Entry) {
        entries.removeAll { $0 == entry }
        persist()
    }

    /// Search over every zone macOS knows, matching city or region.
    static func matches(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return TimeZone.knownTimeZoneIdentifiers
            .filter { $0.localizedCaseInsensitiveContains(trimmed) }
            .prefix(40)
            .map { $0 }
    }

    private func persist() {
        defaults.set(entries.map(\.identifier), forKey: Self.key)
    }
}
