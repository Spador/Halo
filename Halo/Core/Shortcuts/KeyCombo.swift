import AppKit
import Carbon.HIToolbox

/// Everything a global hotkey can do. New actions appear automatically in
/// the Settings Shortcuts tab. No action ships with a default combo: the
/// user assigns them, so Halo never silently claims a shortcut another app
/// relies on.
enum HotKeyAction: String, CaseIterable, Identifiable {
    case toggleNotch
    case openNowPlaying
    case openShelf
    case openControls
    case openCalendar
    case openTimer
    case openPomodoro
    case openStats

    var id: String { rawValue }

    var label: String {
        switch self {
        case .toggleNotch: String(localized: "Open or close the notch")
        case .openNowPlaying: String(localized: "Open Now Playing")
        case .openShelf: String(localized: "Open the shelf")
        case .openControls: String(localized: "Open control sliders")
        case .openCalendar: String(localized: "Open the calendar")
        case .openTimer: String(localized: "Open quick timers")
        case .openPomodoro: String(localized: "Open Pomodoro")
        case .openStats: String(localized: "Open system stats")
        }
    }

    /// The card this action jumps to; nil for toggle.
    var card: NotchCard? {
        switch self {
        case .toggleNotch: nil
        case .openNowPlaying: .nowPlaying
        case .openShelf: .shelf
        case .openControls: .controls
        case .openCalendar: .calendar
        case .openTimer: .timer
        case .openPomodoro: .pomodoro
        case .openStats: .stats
        }
    }
}

/// A recorded key combination. The display label is captured at record time
/// (from the actual keyboard layout), so persistence never needs to reverse
/// a key code into a character.
struct KeyCombo: Codable, Equatable {
    var keyCode: UInt16
    var modifierRawValue: UInt
    var keyLabel: String

    /// Builds a combo from a key-down event, or nil when the combination
    /// would make a bad hotkey (no command, control, or option held —
    /// letters alone would hijack normal typing).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard !flags.intersection([.command, .control, .option]).isEmpty else { return nil }
        keyCode = event.keyCode
        modifierRawValue = flags.rawValue
        keyLabel = Self.label(for: event)
    }

    /// Human-readable form, standard macOS modifier order: ⌃⌥⇧⌘.
    var display: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifierRawValue)
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option) { text += "⌥" }
        if flags.contains(.shift) { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + keyLabel
    }

    /// The same modifiers in the flag format `RegisterEventHotKey` expects.
    var carbonModifiers: UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: modifierRawValue)
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }

    private static let specialKeyLabels: [Int: String] = [
        kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦", kVK_Escape: "⎋", kVK_Home: "↖", kVK_End: "↘",
        kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_LeftArrow: "←", kVK_RightArrow: "→",
        kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func label(for event: NSEvent) -> String {
        if let special = specialKeyLabels[Int(event.keyCode)] { return special }
        return event.charactersIgnoringModifiers?.uppercased() ?? "?"
    }
}
