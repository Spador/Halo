import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchPanelController?
    private var nowPlaying: NowPlayingViewModel?
    private var shelf: ShelfViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let nowPlaying = NowPlayingViewModel()
        let shelf = ShelfViewModel()
        let controller = NotchPanelController(
            screen: screen,
            nowPlaying: nowPlaying,
            shelf: shelf
        )
        controller.show()
        self.nowPlaying = nowPlaying
        self.shelf = shelf
        notchController = controller
    }
}
