import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchPanelController?
    private var nowPlaying: NowPlayingViewModel?
    private var shelf: ShelfViewModel?
    private var hud: HUDCoordinator?

    private var stats: StatsViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let nowPlaying = NowPlayingViewModel()
        let shelf = ShelfViewModel()
        let battery = BatteryMonitor()
        let stats = StatsViewModel(battery: battery)
        let controller = NotchPanelController(
            screen: screen,
            nowPlaying: nowPlaying,
            shelf: shelf,
            stats: stats
        )
        controller.show()

        let hud = HUDCoordinator { [weak controller] state in
            controller?.showHUD(state)
        }
        hud.start()

        // Plugging in the charger flashes a green battery HUD in the wings.
        battery.onChargingBegan = { [weak controller] status in
            controller?.showHUD(
                HUDState(kind: .battery, level: Double(status.percent) / 100)
            )
        }

        self.nowPlaying = nowPlaying
        self.shelf = shelf
        self.hud = hud
        self.stats = stats
        notchController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.shutdown()
    }
}
