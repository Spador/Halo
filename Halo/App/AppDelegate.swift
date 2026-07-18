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
    /// Latest live activity from each engine, merged for the wings.
    private var timerActivity: LiveActivity?
    private var pomodoroActivity: LiveActivity?

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

        // Both engines can run at once; the wings show the quick timer
        // when both are active (it's usually the shorter, more urgent one).
        quickTimer.onLiveActivityChanged = { [weak self, weak controller] activity in
            guard let self else { return }
            self.timerActivity = activity
            controller?.setLiveActivity(self.timerActivity ?? self.pomodoroActivity)
        }
        pomodoro.onLiveActivityChanged = { [weak self, weak controller] activity in
            guard let self else { return }
            self.pomodoroActivity = activity
            controller?.setLiveActivity(self.timerActivity ?? self.pomodoroActivity)
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
        notchController = controller
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.shutdown()
    }
}
