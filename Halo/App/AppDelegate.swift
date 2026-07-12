import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchPanelController?
    private var nowPlaying: NowPlayingViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let nowPlaying = NowPlayingViewModel()
        let controller = NotchPanelController(screen: screen, nowPlaying: nowPlaying)
        controller.show()
        self.nowPlaying = nowPlaying
        notchController = controller
    }
}
