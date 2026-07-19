import AppKit
import Observation

/// One captured clipboard entry. Text only for now.
struct ClipboardItem: Identifiable, Equatable {
    let id: UUID
    let text: String
    var capturedAt: Date
    var isPinned: Bool

    /// Single-line preview for the list.
    var preview: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
    }
}

/// Watches the general pasteboard and keeps a local-only history.
///
/// Honest note on polling: macOS has no pasteboard-changed notification,
/// so every clipboard manager polls `changeCount`. That is one integer
/// comparison per second, and only while the feature is enabled.
///
/// Privacy rules, none of them optional:
/// - Entries marked concealed or transient (the convention password
///   managers use) are never captured.
/// - History lives in memory only and dies with the app. Pinned items are
///   the exception: pinning is an explicit "keep this", so pins persist
///   in the app preferences.
@Observable
final class ClipboardHistory {
    private(set) var items: [ClipboardItem] = []

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var lastChangeCount = 0
    @ObservationIgnored private let defaults: UserDefaults

    private static let maxUnpinned = 50
    private static let pinnedKey = "clipboard.pinnedItems"
    private static let excludedTypes = [
        NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
        NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
    ]

    private struct PinnedRecord: Codable {
        var text: String
        var capturedAt: Date
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.pinnedKey),
           let records = try? JSONDecoder().decode([PinnedRecord].self, from: data) {
            items = records.map {
                ClipboardItem(
                    id: UUID(),
                    text: $0.text,
                    capturedAt: $0.capturedAt,
                    isPinned: true
                )
            }
        }
    }

    // MARK: - Monitoring

    func start() {
        guard pollTask == nil else { return }
        // Skip whatever is on the pasteboard right now: capturing starts
        // with the first copy made after enabling.
        lastChangeCount = NSPasteboard.general.changeCount
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.checkPasteboard()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let types = pasteboard.types ?? []
        guard !types.contains(where: Self.excludedTypes.contains) else { return }
        guard let text = pasteboard.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        capture(text)
    }

    private func capture(_ text: String) {
        if let index = items.firstIndex(where: { $0.text == text }) {
            // Same content again: bump it to the front, keep its pin.
            var existing = items.remove(at: index)
            existing.capturedAt = Date()
            items.insert(existing, at: 0)
        } else {
            items.insert(
                ClipboardItem(id: UUID(), text: text, capturedAt: Date(), isPinned: false),
                at: 0
            )
        }
        trim()
    }

    private func trim() {
        var unpinnedSeen = 0
        items.removeAll { item in
            guard !item.isPinned else { return false }
            unpinnedSeen += 1
            return unpinnedSeen > Self.maxUnpinned
        }
    }

    // MARK: - Actions

    /// Puts the entry back on the pasteboard, ready to paste anywhere.
    func copyToPasteboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        // Our own write must not be re-captured as a new entry.
        lastChangeCount = pasteboard.changeCount
        capture(item.text)
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        trim()
        persistPins()
    }

    func remove(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        if item.isPinned { persistPins() }
    }

    /// Clears the history but keeps pinned entries — those were an
    /// explicit "keep this".
    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
    }

    private func persistPins() {
        let records = items.filter(\.isPinned).map {
            PinnedRecord(text: $0.text, capturedAt: $0.capturedAt)
        }
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: Self.pinnedKey)
        }
    }
}
