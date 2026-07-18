import SwiftUI

/// A button that records a key combination for one hotkey action. Click to
/// arm it, press a combo to assign, Escape cancels, Delete clears. While
/// armed, a local event monitor sees only keystrokes typed into the
/// Settings window itself.
struct ShortcutRecorder: View {
    let action: HotKeyAction
    let settings: SettingsStore

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(title) {
            isRecording ? stopRecording() : startRecording()
        }
        .foregroundStyle(isRecording ? .orange : .primary)
        .onDisappear { stopRecording() }
    }

    private var title: String {
        if isRecording { return String(localized: "Press a shortcut...") }
        return settings.binding(for: action)?.display ?? String(localized: "Record")
    }

    private func startRecording() {
        isRecording = true
        // Let go of every registered hotkey while recording, so pressing an
        // assigned combo re-records it instead of triggering its action.
        settings.setHotKeyRecording(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            defer { stopRecording() }
            switch Int(event.keyCode) {
            case 53:  // Escape cancels
                break
            case 51:  // Delete clears the binding
                settings.setBinding(nil, for: action)
            default:
                // Nil means no command/control/option held; treat as cancel.
                if let combo = KeyCombo(event: event) {
                    settings.setBinding(combo, for: action)
                }
            }
            return nil  // Swallow the keystroke either way.
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard isRecording else { return }
        isRecording = false
        settings.setHotKeyRecording(false)
    }
}
