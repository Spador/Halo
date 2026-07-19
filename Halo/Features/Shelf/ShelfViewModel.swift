import AppKit
import Observation

/// State and actions for the file shelf. Unpinned items live only in
/// memory, so quitting clears them automatically; pinned items persist as
/// plain file paths in the app's preferences (no file contents are stored).
@Observable
final class ShelfViewModel {
    private(set) var items: [ShelfItem] = []
    /// Tiles picked for a group drag (item ids, which are file paths).
    private(set) var selectedIDs: Set<String> = []

    @ObservationIgnored private let defaults = UserDefaults.standard
    private static let pinnedPathsKey = "shelf.pinnedPaths"

    var hasItems: Bool { !items.isEmpty }

    init() {
        let pinnedPaths = defaults.stringArray(forKey: Self.pinnedPathsKey) ?? []
        items = pinnedPaths
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { ShelfItem(url: URL(fileURLWithPath: $0), isPinned: true) }
    }

    func add(_ urls: [URL]) {
        let existing = Set(items.map(\.id))
        let newItems = urls
            .filter { !existing.contains($0.path) }
            .map { ShelfItem(url: $0) }
        items.insert(contentsOf: newItems, at: 0)
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        selectedIDs.remove(item.id)
        persistPinned()
    }

    // MARK: - Group selection

    func toggleSelection(_ item: ShelfItem) {
        selectedIDs.formSymmetricDifference([item.id])
    }

    func clearSelection() {
        selectedIDs = []
    }

    /// Selected file URLs in shelf order, for the group drag.
    var selectedURLs: [URL] {
        items.filter { selectedIDs.contains($0.id) }.map(\.url)
    }

    func togglePin(_ item: ShelfItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        persistPinned()
    }

    func clearUnpinned() {
        items.removeAll { !$0.isPinned }
        selectedIDs.formIntersection(items.map(\.id))
    }

    func airDrop(_ item: ShelfItem) {
        guard let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: [item.url])
        else { return }
        // The AirDrop picker is a regular window; briefly activating Halo
        // makes sure it appears in front.
        NSApplication.shared.activate()
        service.perform(withItems: [item.url])
    }

    func revealInFinder(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    private func persistPinned() {
        defaults.set(
            items.filter(\.isPinned).map(\.url.path),
            forKey: Self.pinnedPathsKey
        )
    }
}
