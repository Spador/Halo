import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchPanelController?
    private var nowPlaying: NowPlayingViewModel?
    private var shelf: ShelfViewModel?
    private var hud: HUDCoordinator?

    private var stats: StatsViewModel?
    private var calendar: CalendarService?
    private var quickTimer: QuickTimerEngine?
    private var pomodoro: PomodoroEngine?
    private var liveActivities: LiveActivityEngine?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let settings = SettingsStore.shared
        let nowPlaying = NowPlayingViewModel()
        let shelf = ShelfViewModel()
        let battery = BatteryMonitor()
        let stats = StatsViewModel(battery: battery)
        let calendar = CalendarService()
        let quickTimer = QuickTimerEngine()
        let pomodoro = PomodoroEngine()
        let controller = NotchPanelController(
            screen: screen,
            nowPlaying: nowPlaying,
            shelf: shelf,
            stats: stats,
            calendar: calendar,
            quickTimer: quickTimer,
            pomodoro: pomodoro
        )
        controller.show()

        // Every feature publishes its live activity to the engine, which
        // ranks them and hands the controller at most two to display.
        let liveActivities = LiveActivityEngine()
        liveActivities.onDisplayChanged = { [weak controller] items in
            controller?.setLiveActivities(items)
        }
        quickTimer.onLiveActivityChanged = { [weak liveActivities] activity in
            liveActivities?.publish(activity, from: .quickTimer)
        }
        pomodoro.onLiveActivityChanged = { [weak liveActivities] activity in
            liveActivities?.publish(activity, from: .pomodoro)
        }

        let hud = HUDCoordinator { [weak controller] state in
            controller?.showHUD(state)
        }

        // Services behind a feature flag only run while the flag is on.
        if settings.isEnabled(.nowPlaying) { nowPlaying.start() }
        if settings.isEnabled(.hud) { hud.start() }

        // React to toggles flipped in Settings while the app runs.
        settings.onFeatureChanged = { [weak self] feature, enabled in
            guard let self else { return }
            switch feature {
            case .nowPlaying:
                enabled ? self.nowPlaying?.start() : self.nowPlaying?.shutdown()
            case .hud:
                enabled ? self.hud?.start() : self.hud?.stop()
            case .timer:
                // Turning the page off cancels a running countdown so its
                // live activity doesn't linger in the wings.
                if !enabled { self.quickTimer?.cancel() }
            case .pomodoro:
                if !enabled { self.pomodoro?.reset() }
            case .shelf, .stats, .calendar:
                break  // Purely view-level; the shell hides them.
            }
        }

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
        self.calendar = calendar
        self.quickTimer = quickTimer
        self.pomodoro = pomodoro
        self.liveActivities = liveActivities
        notchController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.shutdown()
    }
}
