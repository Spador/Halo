import AppKit
import Observation

/// Toggles Focus / Do Not Disturb by running a user-created shortcut
/// named "Halo Focus".
///
/// macOS has no public API for Focus. The Shortcuts app's "Set Focus"
/// action is Apple's supported surface, so Halo delegates to it: the user
/// creates one shortcut (Set Focus, Toggle, Do Not Disturb) and Halo runs
/// it by name. Stateless by design — reading the real Focus state would
/// need Full Disk Access or a private framework, so Control Center stays
/// the source of truth for on and off.
@Observable
final class FocusToggle {
    static let shortcutName = "Halo Focus"

    /// True while the shortcut runs; the chip dims briefly.
    private(set) var isRunning = false
    /// Set when the last run failed — almost always because the shortcut
    /// does not exist yet.
    private(set) var needsSetup = false

    func toggle() {
        guard !isRunning else { return }
        isRunning = true
        needsSetup = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", Self.shortcutName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { process in
            let failed = process.terminationStatus != 0
            Task { @MainActor [weak self] in
                self?.isRunning = false
                self?.needsSetup = failed
            }
        }
        do {
            try process.run()
        } catch {
            isRunning = false
            needsSetup = true
        }
    }

    /// Opens the Shortcuts app on a fresh shortcut for the user to fill
    /// in: Set Focus, Toggle, Do Not Disturb, named "Halo Focus".
    func openShortcutsApp() {
        guard let url = URL(string: "shortcuts://create-shortcut") else { return }
        NSWorkspace.shared.open(url)
    }
}
