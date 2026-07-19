import Foundation

/// What the notch HUD is currently showing: which control, at what level.
struct HUDState: Equatable {
    enum Kind {
        case volume
        case brightness
        case battery      // charger-connected flash (green)
        case batteryLow   // low-battery warning flash (red)
    }

    var kind: Kind
    /// 0...1
    var level: Double
    var muted = false

    /// Level to draw — a muted volume bar shows empty regardless of level.
    var displayLevel: Double { muted ? 0 : level }

    var iconName: String {
        switch kind {
        case .battery:
            return "bolt.fill"
        case .batteryLow:
            return "battery.25percent"
        case .brightness:
            return "sun.max.fill"
        case .volume:
            if muted { return "speaker.slash.fill" }
            switch level {
            case 0: return "speaker.fill"
            case ..<0.34: return "speaker.wave.1.fill"
            case ..<0.67: return "speaker.wave.2.fill"
            default: return "speaker.wave.3.fill"
            }
        }
    }
}
