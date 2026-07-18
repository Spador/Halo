import AppKit
import SwiftUI

/// Owns the notch panel: creates it, positions it over the notch, and
/// resizes it between the collapsed (notch-sized) and expanded frames.
///
/// The window is kept exactly as small as the visible content so that when
/// collapsed it can never swallow clicks meant for the menu bar around it.
final class NotchPanelController: NSObject {
    private let panel: NotchPanel
    private let viewModel = NotchViewModel()
    private let shelf: ShelfViewModel
    private let settings: SettingsStore
    private var geometry: NotchGeometry
    private var collapseTask: Task<Void, Never>?
    private var expandTask: Task<Void, Never>?
    private var shrinkTask: Task<Void, Never>?
    private var hudHideTask: Task<Void, Never>?

    /// Grace period after the pointer leaves before collapsing, so grazing
    /// the edge doesn't make the overlay flicker.
    private static let collapseGracePeriod: Duration = .milliseconds(120)
    /// How long the collapse spring runs before the window shrinks under it.
    private static let shrinkDelay: Duration = .milliseconds(450)
    /// How long a volume/brightness flash stays before auto-hiding.
    private static let hudDisplayDuration: Duration = .milliseconds(1500)

    init(
        screen: NSScreen,
        nowPlaying: NowPlayingViewModel,
        shelf: ShelfViewModel,
        stats: StatsViewModel,
        calendar: CalendarService,
        quickTimer: QuickTimerEngine,
        pomodoro: PomodoroEngine,
        settings: SettingsStore = .shared
    ) {
        geometry = NotchGeometry(screen: screen)
        panel = NotchPanel(contentRect: geometry.notchRect)
        self.shelf = shelf
        self.settings = settings
        super.init()

        viewModel.notchSize = geometry.notchRect.size

        let hoverView = HoverTrackingView()
        let hostingView = NSHostingView(
            rootView: NotchShellView(
                viewModel: viewModel,
                nowPlaying: nowPlaying,
                shelf: shelf,
                stats: stats,
                calendar: calendar,
                quickTimer: quickTimer,
                pomodoro: pomodoro
            )
        )
        // Don't let SwiftUI dictate the window size — the controller owns it.
        hostingView.sizingOptions = []
        hoverView.addSubview(hostingView)
        hostingView.frame = hoverView.bounds
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hoverView

        hoverView.onPointerEntered = { [weak self] in self?.pointerDidEnter() }
        hoverView.onPointerExited = { [weak self] in self?.pointerDidExit() }
        hoverView.onClicked = { [weak self] in self?.expand() }
        hoverView.onDragEntered = { [weak self] in self?.dragDidEnter() }
        hoverView.onDragExited = { [weak self] in self?.dragDidExit() }
        hoverView.onDropped = { [weak self] urls in self?.handleDrop(urls) }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func show() {
        panel.setFrame(geometry.notchRect, display: true)
        // orderFrontRegardless: show the panel even though the app never
        // becomes the active application.
        panel.orderFrontRegardless()
    }

    /// Pointer hover honors the user's trigger setting; a click (below, via
    /// `onClicked`) and an incoming file drag always open the panel.
    private func pointerDidEnter() {
        collapseTask?.cancel()
        guard settings.expandTrigger == .hover, !viewModel.isExpanded else { return }
        expandTask?.cancel()
        let delay = settings.hoverDelayMilliseconds
        guard delay > 0 else {
            expand()
            return
        }
        expandTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            self?.expand()
        }
    }

    private func pointerDidExit() {
        expandTask?.cancel()
        scheduleCollapse()
    }

    private func expand() {
        collapseTask?.cancel()
        shrinkTask?.cancel()
        guard !viewModel.isExpanded else { return }
        // Grow the window first — invisible, since its background is clear —
        // then let SwiftUI spring the black shape into the new space.
        panel.setFrame(expandedFrame, display: true)
        viewModel.isExpanded = true
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { [weak self] in
            try? await Task.sleep(for: Self.collapseGracePeriod)
            guard !Task.isCancelled else { return }
            self?.collapse()
        }
    }

    private func collapse() {
        viewModel.isExpanded = false
        // Shrink the window only after the spring has visually finished;
        // shrinking immediately would clip the animation mid-flight.
        scheduleShrinkToRestFrame()
    }

    /// The window size when not expanded: notch-sized normally, wing-sized
    /// while a HUD flash or live activity is showing.
    private var restFrame: CGRect {
        viewModel.hud != nil || viewModel.liveActivity != nil
            ? hudFrame
            : geometry.notchRect
    }

    // MARK: - Live activity (running timer in the wings)

    /// Updates the persistent wing display. The window only re-frames when
    /// the activity appears or disappears — per-second text updates reuse
    /// the existing frame.
    func setLiveActivity(_ activity: LiveActivity?) {
        let hadWings = viewModel.liveActivity != nil
        viewModel.liveActivity = activity
        let hasWings = activity != nil
        guard hadWings != hasWings,
              !viewModel.isExpanded,
              viewModel.hud == nil
        else { return }
        if hasWings {
            shrinkTask?.cancel()
            panel.setFrame(hudFrame, display: true)
        } else {
            scheduleShrinkToRestFrame()
        }
    }

    private func scheduleShrinkToRestFrame() {
        shrinkTask?.cancel()
        shrinkTask = Task { [weak self] in
            try? await Task.sleep(for: Self.shrinkDelay)
            guard !Task.isCancelled, let self, !self.viewModel.isExpanded else { return }
            self.panel.setFrame(self.restFrame, display: true)
        }
    }

    // MARK: - Volume/brightness HUD

    func showHUD(_ state: HUDState) {
        if !viewModel.isExpanded {
            shrinkTask?.cancel()
            panel.setFrame(hudFrame, display: true)
        }
        viewModel.hud = state

        hudHideTask?.cancel()
        hudHideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.hudDisplayDuration)
            guard !Task.isCancelled else { return }
            self?.hideHUD()
        }
    }

    private func hideHUD() {
        viewModel.hud = nil
        guard !viewModel.isExpanded else { return }
        scheduleShrinkToRestFrame()
    }

    private var hudFrame: CGRect {
        let notch = geometry.notchRect
        let width = notch.width + 2 * NotchViewModel.hudWingWidth
        let height = notch.height + NotchViewModel.hudExtraHeight
        return CGRect(
            x: notch.midX - width / 2,
            y: notch.maxY - height,
            width: width,
            height: height
        )
    }

    // MARK: - File drags

    private func dragDidEnter() {
        viewModel.isDropTargeted = true
        expand()
    }

    private func dragDidExit() {
        viewModel.isDropTargeted = false
        scheduleCollapse()
    }

    private func handleDrop(_ urls: [URL]) {
        viewModel.isDropTargeted = false
        shelf.add(urls)
        // Show the result of the drop even if another card was selected.
        viewModel.selectedCard = .shelf
    }

    /// Recomputes position when displays are plugged in/out, resolution
    /// changes, or the notched screen disappears (e.g. lid closed).
    @objc private func screenParametersDidChange() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        geometry = NotchGeometry(screen: screen)
        viewModel.notchSize = geometry.notchRect.size
        viewModel.isExpanded = false
        viewModel.hud = nil
        panel.setFrame(geometry.notchRect, display: true)
    }

    private var expandedFrame: CGRect {
        let notch = geometry.notchRect
        let width = max(NotchViewModel.expandedSize.width, notch.width)
        let height = NotchViewModel.expandedSize.height
        return CGRect(
            x: notch.midX - width / 2,
            y: notch.maxY - height,
            width: width,
            height: height
        )
    }
}
