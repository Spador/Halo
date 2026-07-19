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

    // MARK: - Quick file actions

    enum ImageFormat: String {
        case png
        case jpeg

        var fileType: NSBitmapImageRep.FileType {
            switch self {
            case .png: .png
            case .jpeg: .jpeg
            }
        }
    }

    /// Zips the given files into one archive next to the first source and
    /// puts the archive on the shelf. Sources are staged into a temporary
    /// folder first so several files (and whole folders) archive cleanly.
    func compress(_ urls: [URL]) {
        guard let first = urls.first else { return }
        let directory = first.deletingLastPathComponent()
        let baseName = urls.count == 1
            ? first.deletingPathExtension().lastPathComponent
            : "Archive"
        let destination = Self.uniqueURL(in: directory, name: baseName, ext: "zip")

        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("halo-zip-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(
                at: staging, withIntermediateDirectories: true
            )
            for url in urls {
                try FileManager.default.copyItem(
                    at: url,
                    to: staging.appendingPathComponent(url.lastPathComponent)
                )
            }
        } catch {
            try? FileManager.default.removeItem(at: staging)
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", staging.path, destination.path]
        process.terminationHandler = { process in
            let succeeded = process.terminationStatus == 0
            Task { @MainActor [weak self] in
                try? FileManager.default.removeItem(at: staging)
                if succeeded { self?.add([destination]) }
            }
        }
        try? process.run()
    }

    /// Converts an image to the format, writes it beside the original,
    /// and puts the result on the shelf. The original is untouched.
    func convertImage(_ item: ShelfItem, to format: ImageFormat) {
        guard let data = try? Data(contentsOf: item.url),
              let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let converted = rep.representation(
                  using: format.fileType,
                  properties: [.compressionFactor: 0.9]
              )
        else { return }

        let destination = Self.uniqueURL(
            in: item.url.deletingLastPathComponent(),
            name: item.url.deletingPathExtension().lastPathComponent,
            ext: format.rawValue
        )
        guard (try? converted.write(to: destination)) != nil else { return }
        add([destination])
    }

    /// Renames the real file on disk, then updates the shelf reference,
    /// keeping pin state. A name collision or failed move changes nothing.
    func rename(_ item: ShelfItem, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != item.name,
              !trimmed.contains("/")
        else { return }
        let destination = item.url.deletingLastPathComponent()
            .appendingPathComponent(trimmed)
        guard !FileManager.default.fileExists(atPath: destination.path),
              (try? FileManager.default.moveItem(at: item.url, to: destination)) != nil
        else { return }

        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        selectedIDs.remove(item.id)
        items[index] = ShelfItem(url: destination, isPinned: item.isPinned)
        persistPinned()
    }

    /// name.ext, else name 2.ext, name 3.ext ...
    private static func uniqueURL(in directory: URL, name: String, ext: String) -> URL {
        var candidate = directory.appendingPathComponent("\(name).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(name) \(counter).\(ext)")
            counter += 1
        }
        return candidate
    }

    private func persistPinned() {
        defaults.set(
            items.filter(\.isPinned).map(\.url.path),
            forKey: Self.pinnedPathsKey
        )
    }
}
