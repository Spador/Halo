import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchPanelController?
    private var nowPlaying: NowPlayingViewModel?
    private var shelf: ShelfViewModel?
    private var hud: HUDCoordinator?

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

        let hud = HUDCoordinator { [weak controller] state in
            controller?.showHUD(state)
        }
        hud.start()

        self.nowPlaying = nowPlaying
        self.shelf = shelf
        self.hud = hud
        notchController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.shutdown()
    }
}
