import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let controller = NotchPanelController(screen: screen)
        controller.show()
        notchController = controller
    }
}
