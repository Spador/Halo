import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var notchController: NotchPanelController?
    private var nowPlaying: NowPlayingViewModel?
    private var shelf: ShelfViewModel?
    private var hud: HUDCoordinator?

    private var stats: StatsViewModel?
    private var calendar: CalendarService?
    private var quickTimer: QuickTimerEngine?
    private var pomodoro: PomodoroEngine?
    private var liveActivities: LiveActivityEngine?
    private var hotKeys: HotKeyCenter?
    private var clipboard: ClipboardHistory?
    private var screenshots: ScreenshotWatcher?
    private var meetings: MeetingCountdown?
    private var sensors: SensorInUseMonitor?
    private var onboardingWindow: NSWindow?

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
        // One volume backend and one display manager, shared by the HUD
        // keys and the control sliders so their levels never disagree.
        let volume = VolumeControl()
        let displays = DisplayBrightnessManager()
        let controls = ControlsViewModel(volume: volume, displays: displays)
        let clipboard = ClipboardHistory()
        let meetings = MeetingCountdown(calendar: calendar)
        let colorPicker = ColorPickerStore()
        let controller = NotchPanelController(
            screen: screen,
            nowPlaying: nowPlaying,
            shelf: shelf,
            controls: controls,
            clipboard: clipboard,
            meetings: meetings,
            colorPicker: colorPicker,
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
        nowPlaying.onInfoChanged = { [weak self] info in
            self?.publishMediaActivity(info)
        }
        meetings.onLiveActivityChanged = { [weak liveActivities] activity in
            liveActivities?.publish(activity, from: .meeting)
        }
        calendar.onChanged = { [weak meetings] in
            meetings?.refresh()
        }
        meetings.refresh()

        // Privacy indicator: mic or camera in use, anywhere on the system.
        let sensors = SensorInUseMonitor()
        sensors.onLiveActivityChanged = { [weak liveActivities] activity in
            liveActivities?.publish(activity, from: .recording)
        }
        if settings.isEnabled(.sensors) { sensors.start() }

        let hud = HUDCoordinator(volume: volume, brightness: displays) {
            [weak controller] state in
            controller?.showHUD(state)
            // Keep the sliders in step when keys change a level.
            controls.refresh()
        }

        // Services behind a feature flag only run while the flag is on.
        if settings.isEnabled(.nowPlaying) { nowPlaying.start() }
        if settings.isEnabled(.hud) { hud.start() }
        if settings.isEnabled(.clipboard) { clipboard.start() }

        // New screenshots land on the shelf.
        let screenshots = ScreenshotWatcher()
        screenshots.onScreenshot = { [weak shelf] url in
            shelf?.add([url])
        }
        if settings.isEnabled(.screenshots) { screenshots.start() }

        // React to toggles flipped in Settings while the app runs.
        settings.onFeatureChanged = { [weak self] feature, enabled in
            guard let self else { return }
            switch feature {
            case .nowPlaying:
                enabled ? self.nowPlaying?.start() : self.nowPlaying?.shutdown()
            case .hud:
                enabled ? self.hud?.start() : self.hud?.stop()
            case .clipboard:
                enabled ? self.clipboard?.start() : self.clipboard?.stop()
            case .screenshots:
                enabled ? self.screenshots?.start() : self.screenshots?.stop()
            case .meetings:
                enabled ? self.meetings?.refresh() : self.meetings?.stop()
            case .sensors:
                enabled ? self.sensors?.start() : self.sensors?.stop()
            case .timer:
                // Turning the page off cancels a running countdown so its
                // live activity doesn't linger in the wings.
                if !enabled { self.quickTimer?.cancel() }
            case .pomodoro:
                if !enabled { self.pomodoro?.reset() }
            case .mediaActivity:
                // Re-evaluate with the flag's new value.
                self.publishMediaActivity(self.nowPlaying?.info)
            case .shelf, .controls, .scrollVolume, .gestures, .colorPicker,
                .stats, .calendar:
                break  // View-level or checked at use; nothing to stop.
            }
        }

        // Scrolling over the collapsed notch adjusts the volume.
        controller.onVolumeScroll = { [weak hud] delta in
            guard SettingsStore.shared.isEnabled(.scrollVolume) else { return }
            hud?.adjustVolume(by: delta)
        }

        // Horizontal swipes over the collapsed notch skip tracks.
        controller.onTrackSwipe = { [weak nowPlaying] next in
            next ? nowPlaying?.nextTrack() : nowPlaying?.previousTrack()
        }

        // Global shortcuts jump straight to a page from any app.
        let hotKeys = HotKeyCenter()
        hotKeys.onAction = { [weak controller] action in
            if let card = action.card {
                controller?.openCard(card)
            } else {
                controller?.toggleExpanded()
            }
        }
        hotKeys.apply(settings.typedHotKeyBindings())
        settings.onHotKeysChanged = { [weak self] in
            guard let self, let hotKeys = self.hotKeys else { return }
            hotKeys.apply(SettingsStore.shared.typedHotKeyBindings())
        }
        settings.onHotKeyRecordingChanged = { [weak self] recording in
            guard let hotKeys = self?.hotKeys else { return }
            recording ? hotKeys.suspend() : hotKeys.resume()
        }

        // Plugging in the charger flashes a green battery HUD in the wings;
        // sinking through 20 and 10 percent flashes a red warning.
        battery.onChargingBegan = { [weak controller] status in
            controller?.showHUD(
                HUDState(kind: .battery, level: Double(status.percent) / 100)
            )
        }
        battery.onLowBattery = { [weak controller] status in
            controller?.showHUD(
                HUDState(kind: .batteryLow, level: Double(status.percent) / 100)
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
        self.hotKeys = hotKeys
        self.clipboard = clipboard
        self.screenshots = screenshots
        self.meetings = meetings
        self.sensors = sensors
        notchController = controller
        // The stream may have delivered before the engine reference was
        // stored above; publish once to catch up.
        publishMediaActivity(nowPlaying.info)

        settings.onReplayOnboardingRequested = { [weak self] in
            self?.showOnboarding()
        }
        if !settings.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        nowPlaying?.shutdown()
    }

    /// Music holds a wing only while actually playing; pausing clears it.
    private func publishMediaActivity(_ info: NowPlayingInfo?) {
        let activity: LiveActivity? = {
            guard SettingsStore.shared.isEnabled(.mediaActivity),
                  let info, info.isPlaying
            else { return nil }
            return LiveActivity(
                iconName: "music.note",
                text: info.title,
                emphasized: false,
                artwork: info.artwork,
                isMedia: true
            )
        }()
        liveActivities?.publish(activity, from: .media)
    }

    // MARK: - Onboarding window

    private func showOnboarding() {
        if let onboardingWindow {
            onboardingWindow.makeKeyAndOrderFront(nil)
            return
        }
        let view = OnboardingView(settings: .shared) { [weak self] in
            self?.finishOnboarding()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.title = ""
        // We keep the reference and drop it in windowWillClose.
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        onboardingWindow = window
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func finishOnboarding() {
        SettingsStore.shared.hasCompletedOnboarding = true
        onboardingWindow?.close()
    }

    /// Closing the window with the red button counts as done too — the
    /// tour must never nag on the next launch.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window === onboardingWindow
        else { return }
        SettingsStore.shared.hasCompletedOnboarding = true
        onboardingWindow = nil
    }
}
