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
    case gestures
    case mediaActivity
    case clipboard
    case screenshots
    case stats
    case calendar
    case timer
    case pomodoro

    var id: String { rawValue }

    /// Most features ship on. Privacy-sensitive ones ship off and wait for
    /// an explicit opt-in in Settings.
    var enabledByDefault: Bool {
        switch self {
        case .clipboard: false
        default: true
        }
    }

    var label: String {
        switch self {
        case .nowPlaying: String(localized: "Now Playing")
        case .shelf: String(localized: "File shelf")
        case .hud: String(localized: "Volume and brightness HUD")
        case .controls: String(localized: "Control sliders")
        case .scrollVolume: String(localized: "Scroll wheel volume")
        case .gestures: String(localized: "Trackpad gestures")
        case .mediaActivity: String(localized: "Music in the wings")
        case .clipboard: String(localized: "Clipboard history")
        case .screenshots: String(localized: "Screenshots to shelf")
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
        case .gestures: "hand.draw.fill"
        case .mediaActivity: "waveform"
        case .clipboard: "doc.on.clipboard"
        case .screenshots: "camera.viewfinder"
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
        case .gestures:
            String(localized: "Swipe on the notch to skip tracks; pinch to open and close.")
        case .mediaActivity:
            String(localized: "Mini artwork and equalizer beside the notch while music plays.")
        case .clipboard:
            String(localized: "Keeps recent copied text, in memory only. Off by default; password manager entries are never captured.")
        case .screenshots:
            String(localized: "New screenshots land on the shelf automatically.")
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
        case .clipboard: .clipboard
        case .calendar: .calendar
        case .timer: .timer
        case .pomodoro: .pomodoro
        case .stats: .stats
        }
    }
}
