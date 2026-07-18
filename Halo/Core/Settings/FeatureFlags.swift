import Foundation

/// Every user-toggleable Halo module. New v2 features add a case here and
/// automatically appear in the Settings Features tab; everything ships
/// enabled unless a feature is risky enough to default off.
enum FeatureID: String, CaseIterable, Identifiable {
    case nowPlaying
    case shelf
    case hud
    case controls
    case scrollVolume
    case stats
    case calendar
    case timer
    case pomodoro

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nowPlaying: String(localized: "Now Playing")
        case .shelf: String(localized: "File shelf")
        case .hud: String(localized: "Volume and brightness HUD")
        case .controls: String(localized: "Control sliders")
        case .scrollVolume: String(localized: "Scroll wheel volume")
        case .stats: String(localized: "System stats")
        case .calendar: String(localized: "Calendar")
        case .timer: String(localized: "Quick timers")
        case .pomodoro: String(localized: "Pomodoro")
        }
    }

    var symbol: String {
        switch self {
        case .nowPlaying: "music.note"
        case .shelf: "tray.fill"
        case .hud: "speaker.wave.2.fill"
        case .controls: "slider.horizontal.3"
        case .scrollVolume: "computermouse.fill"
        case .stats: "chart.bar.fill"
        case .calendar: "calendar"
        case .timer: "timer"
        case .pomodoro: "brain.head.profile"
        }
    }

    /// One-line explanation shown under the toggle in Settings.
    var detail: String {
        switch self {
        case .nowPlaying:
            String(localized: "Media card and controls. Off also stops the helper process.")
        case .shelf:
            String(localized: "Drop files on the notch to hold, drag out, or AirDrop them.")
        case .hud:
            String(localized: "Replaces the system volume and brightness pop ups. Off returns the stock ones.")
        case .controls:
            String(localized: "Volume and brightness sliders in the notch panel.")
        case .scrollVolume:
            String(localized: "Scroll over the collapsed notch to change the volume.")
        case .stats:
            String(localized: "CPU, GPU, RAM, network, and battery readouts.")
        case .calendar:
            String(localized: "Month view of your calendar events.")
        case .timer:
            String(localized: "Quick countdown timers with a live activity.")
        case .pomodoro:
            String(localized: "Focus sessions with work and break rounds.")
        }
    }
}

extension NotchCard {
    /// The feature flag that gates this card.
    var feature: FeatureID {
        switch self {
        case .nowPlaying: .nowPlaying
        case .shelf: .shelf
        case .controls: .controls
        case .calendar: .calendar
        case .timer: .timer
        case .pomodoro: .pomodoro
        case .stats: .stats
        }
    }
}
