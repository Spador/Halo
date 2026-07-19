import SwiftUI

/// The world clock card: one row per city with its local time, offset
/// from here, and a day marker. Ticks once a minute, only while visible.
struct WorldClockPageView: View {
    let store: WorldClockStore
    let settings: SettingsStore

    @State private var isAdding = false
    @State private var search = ""

    var body: some View {
        if isAdding {
            addPanel
        } else {
            clockList
        }
    }

    // MARK: - Clock list

    private var clockList: some View {
        VStack(spacing: 6) {
            TimelineView(.everyMinute) { context in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 2) {
                        ForEach(store.entries) { entry in
                            row(entry, now: context.date)
                        }
                    }
                }
            }
            Button {
                search = ""
                isAdding = true
            } label: {
                Label("Add a city", systemImage: "plus")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 10)
    }

    private func row(_ entry: WorldClockStore.Entry, now: Date) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.cityName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                Text(detailText(entry, now: now))
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.4))
            }
            Spacer(minLength: 8)
            Text(timeText(entry, now: now))
                .font(.system(size: 16, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Remove", role: .destructive) { store.remove(entry) }
        }
    }

    private func timeText(_ entry: WorldClockStore.Entry, now: Date) -> String {
        guard let zone = entry.timeZone else { return "–" }
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: now)
    }

    /// "+9.5h · tomorrow" style: hours ahead or behind, plus a day marker
    /// when the calendar date differs from here.
    private func detailText(_ entry: WorldClockStore.Entry, now: Date) -> String {
        guard let zone = entry.timeZone else { return "" }
        let deltaSeconds = zone.secondsFromGMT(for: now)
            - TimeZone.current.secondsFromGMT(for: now)
        let hours = Double(deltaSeconds) / 3600

        var text: String
        if deltaSeconds == 0 {
            text = String(localized: "same time")
        } else {
            let formatted = hours == hours.rounded()
                ? String(format: "%+.0f", hours)
                : String(format: "%+.1f", hours)
            text = "\(formatted)h"
        }

        var remote = Foundation.Calendar.current
        remote.timeZone = zone
        let localDay = Foundation.Calendar.current.component(.day, from: now)
        let remoteDay = remote.component(.day, from: now)
        if localDay != remoteDay {
            text += deltaSeconds > 0
                ? String(localized: " · tomorrow")
                : String(localized: " · yesterday")
        }
        return text
    }

    // MARK: - Add panel

    private var addPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                TextField("Search cities", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white)
                Button("Cancel") { isAdding = false }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(Capsule().fill(.white.opacity(0.1)))

            ScrollView(showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(WorldClockStore.matches(for: search), id: \.self) { identifier in
                        Button {
                            store.add(identifier)
                            isAdding = false
                        } label: {
                            Text(identifier.replacingOccurrences(of: "_", with: " "))
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.75))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .frame(height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 10)
    }
}
