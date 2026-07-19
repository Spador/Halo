import AppKit

/// Watches Spotlight for newly captured screenshots and hands their URLs
/// to the shelf.
///
/// Why Spotlight instead of watching a folder: the screenshot location is
/// user-configurable, but every capture gets the `kMDItemIsScreenCapture`
/// metadata tag wherever it lands. A live NSMetadataQuery pushes updates —
/// event driven, no polling, no permissions. If the user has disabled
/// Spotlight indexing entirely, this feature silently does nothing.
final class ScreenshotWatcher: NSObject {
    var onScreenshot: (URL) -> Void = { _ in }

    private var query: NSMetadataQuery?
    /// The initial gather lists every screenshot ever taken; only updates
    /// arriving after it finishes are fresh captures.
    private var isGathering = true

    func start() {
        guard query == nil else { return }
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture == 1")
        query.searchScopes = [NSMetadataQueryUserHomeScope]
        query.notificationBatchingInterval = 0.5

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didFinishGathering),
            name: .NSMetadataQueryDidFinishGathering,
            object: query
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didUpdate(_:)),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        self.query = query
        isGathering = true
        query.start()
    }

    func stop() {
        guard let query else { return }
        query.stop()
        NotificationCenter.default.removeObserver(
            self, name: .NSMetadataQueryDidFinishGathering, object: query
        )
        NotificationCenter.default.removeObserver(
            self, name: .NSMetadataQueryDidUpdate, object: query
        )
        self.query = nil
    }

    @objc private func didFinishGathering() {
        isGathering = false
    }

    @objc private func didUpdate(_ notification: Notification) {
        guard !isGathering else { return }
        let added =
            notification.userInfo?[NSMetadataQueryUpdateAddedItemsKey]
            as? [NSMetadataItem] ?? []
        for item in added {
            guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String
            else { continue }
            onScreenshot(URL(fileURLWithPath: path))
        }
    }
}
