import Foundation

/// Every user-toggleable Halo module. New v2 features add a case here and
/// automatically appear in the Settings Features tab; everything ships
/// enabled unless a feature is risky enough to default off.
enum FeatureID: String, CaseIterable, Identifiable {
    case nowPlaying
    case shelf
    case hud
    case stats
    case calendar
    case timer
    case pomodoro

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nowPlaying: "Now Playing"
        case .shelf: "File shelf"
        case .hud: "Volume and brightness HUD"
        case .stats: "System stats"
        case .calendar: "Calendar"
        case .timer: "Quick timers"
        case .pomodoro: "Pomodoro"
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "music.note"
        case .shelf: "tray.fill"
        case .hud: "speaker.wave.2.fill"
        case .stats: "chart.bar.fill"
        case .calendar: "calendar"
        case .timer: "timer"
        case .pomodoro: "brain.head.profile"
        }
    }

    /// One-line explanation shown under the toggle in Settings.
    var detail: String {
        switch self {
        case .nowPlaying: "Media card and controls. Off also stops the helper process."
        case .shelf: "Drop files on the notch to hold, drag out, or AirDrop them."
        case .hud: "Replaces the system volume and brightness pop ups. Off returns the stock ones."
        case .stats: "CPU, GPU, RAM, network, and battery readouts."
        case .calendar: "Month view of your calendar events."
        case .timer: "Quick countdown timers with a live activity."
        case .pomodoro: "Focus sessions with work and break rounds."
        }
    }
}

extension NotchCard {
    /// The feature flag that gates this card.
    var feature: FeatureID {
        switch self {
        case .nowPlaying: .nowPlaying
        case .shelf: .shelf
        case .calendar: .calendar
        case .timer: .timer
        case .pomodoro: .pomodoro
        case .stats: .stats
        }
    }
}
