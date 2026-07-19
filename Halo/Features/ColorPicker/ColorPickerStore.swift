import AppKit
import Observation
import SwiftUI

/// One remembered color, stored as its hex string.
struct Swatch: Identifiable, Equatable {
    let hex: String

    var id: String { hex }

    var color: Color {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// "rgb(64, 128, 255)" for the copy-as-RGB menu item.
    var rgbText: String {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return "rgb(\((value >> 16) & 0xFF), \((value >> 8) & 0xFF), \(value & 0xFF))"
    }
}

/// Runs the system color sampler (the magnifier loupe) and keeps recent
/// picks. The loupe is drawn by macOS itself — Halo never sees the screen,
/// only the single color handed back, so no capture permission exists to
/// ask for. Picks are copied to the clipboard as hex immediately.
@Observable
final class ColorPickerStore {
    private(set) var swatches: [Swatch] = []
    /// The hex just picked or copied, for the brief "copied" confirmation.
    private(set) var lastCopied: String?

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "colorPicker.recentHexes"
    private static let maxSwatches = 12

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        swatches = (defaults.stringArray(forKey: Self.key) ?? []).map(Swatch.init)
    }

    func pick() {
        // The sampler calls back on the main thread but its handler isn't
        // annotated; assumeIsolated states the fact to the compiler.
        NSColorSampler().show { [weak self] picked in
            guard let picked else { return }
            MainActor.assumeIsolated {
                self?.add(picked)
            }
        }
    }

    func copy(_ swatch: Swatch, as text: String? = nil) {
        let payload = text ?? swatch.hex
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(payload, forType: .string)
        lastCopied = payload
    }

    func remove(_ swatch: Swatch) {
        swatches.removeAll { $0 == swatch }
        persist()
    }

    private func add(_ color: NSColor) {
        guard let rgb = color.usingColorSpace(.sRGB) else { return }
        let hex = String(
            format: "#%02X%02X%02X",
            Int(round(rgb.redComponent * 255)),
            Int(round(rgb.greenComponent * 255)),
            Int(round(rgb.blueComponent * 255))
        )
        let swatch = Swatch(hex: hex)
        swatches.removeAll { $0 == swatch }
        swatches.insert(swatch, at: 0)
        if swatches.count > Self.maxSwatches {
            swatches.removeLast(swatches.count - Self.maxSwatches)
        }
        persist()
        copy(swatch)
    }

    private func persist() {
        defaults.set(swatches.map(\.hex), forKey: Self.key)
    }
}
