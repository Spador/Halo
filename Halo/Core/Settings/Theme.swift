import AppKit
import SwiftUI

/// Accent colors for the panel tint and small highlights. Raw values
/// persist in settings.
enum ThemeAccent: String, CaseIterable, Identifiable {
    case teal
    case blue
    case purple
    case pink
    case green
    case amber

    var id: String { rawValue }

    var label: String {
        switch self {
        case .teal: String(localized: "Teal")
        case .blue: String(localized: "Blue")
        case .purple: String(localized: "Purple")
        case .pink: String(localized: "Pink")
        case .green: String(localized: "Green")
        case .amber: String(localized: "Amber")
        }
    }

    /// Full-strength accent for small highlights (active card icon).
    var color: Color { Color(nsColor: nsColor) }

    var nsColor: NSColor {
        switch self {
        case .teal: NSColor(red: 0.15, green: 0.85, blue: 0.90, alpha: 1)
        case .blue: NSColor(red: 0.25, green: 0.55, blue: 1.00, alpha: 1)
        case .purple: NSColor(red: 0.65, green: 0.40, blue: 1.00, alpha: 1)
        case .pink: NSColor(red: 1.00, green: 0.35, blue: 0.65, alpha: 1)
        case .green: NSColor(red: 0.30, green: 0.90, blue: 0.50, alpha: 1)
        case .amber: NSColor(red: 1.00, green: 0.75, blue: 0.25, alpha: 1)
        }
    }
}

/// Central place that turns the appearance settings into the concrete
/// styles views use, so no view hard-codes a themed color.
enum Theme {
    /// Gradient for the expanded panel: black at the top (blending into the
    /// physical notch) fading into a faint accent wash at the bottom.
    /// Teal at strength 1.0 and opacity 1.0 reproduces the v1 look exactly
    /// (0.10 x teal = the old hard-coded bottom color).
    static func panelColors(
        accent: ThemeAccent,
        tintStrength: Double,
        opacity: Double
    ) -> [Color] {
        let bottom =
            NSColor.black.blended(withFraction: 0.10 * tintStrength, of: accent.nsColor)
            ?? .black
        return [
            Color.black.opacity(opacity),
            Color(nsColor: bottom).opacity(opacity),
        ]
    }
}
