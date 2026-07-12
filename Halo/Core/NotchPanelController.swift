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
    private var geometry: NotchGeometry
    private var collapseTask: Task<Void, Never>?
    private var shrinkTask: Task<Void, Never>?

    /// Grace period after the pointer leaves before collapsing, so grazing
    /// the edge doesn't make the overlay flicker.
    private static let collapseGracePeriod: Duration = .milliseconds(120)
    /// How long the collapse spring runs before the window shrinks under it.
    private static let shrinkDelay: Duration = .milliseconds(450)

    init(screen: NSScreen) {
        geometry = NotchGeometry(screen: screen)
        panel = NotchPanel(contentRect: geometry.notchRect)
        super.init()

        viewModel.notchSize = geometry.notchRect.size

        let hoverView = HoverTrackingView()
        let hostingView = NSHostingView(rootView: NotchShellView(viewModel: viewModel))
        // Don't let SwiftUI dictate the window size — the controller owns it.
        hostingView.sizingOptions = []
        hoverView.addSubview(hostingView)
        hostingView.frame = hoverView.bounds
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hoverView

        hoverView.onPointerEntered = { [weak self] in self?.expand() }
        hoverView.onPointerExited = { [weak self] in self?.scheduleCollapse() }

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
        shrinkTask?.cancel()
        shrinkTask = Task { [weak self] in
            try? await Task.sleep(for: Self.shrinkDelay)
            guard !Task.isCancelled, let self, !self.viewModel.isExpanded else { return }
            self.panel.setFrame(self.geometry.notchRect, display: true)
        }
    }

    /// Recomputes position when displays are plugged in/out, resolution
    /// changes, or the notched screen disappears (e.g. lid closed).
    @objc private func screenParametersDidChange() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        geometry = NotchGeometry(screen: screen)
        viewModel.notchSize = geometry.notchRect.size
        viewModel.isExpanded = false
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
