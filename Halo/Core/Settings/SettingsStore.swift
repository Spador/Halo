import Foundation
import Observation

/// How the panel opens when the pointer reaches the notch.
enum ExpandTrigger: String, CaseIterable, Identifiable {
    case hover
    case click

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hover: "Hover"
        case .click: "Click"
        }
    }
}

/// The single source of truth for user preferences.
///
/// Every setting is a plain property that persists itself to `UserDefaults`
/// when it changes. Views bind to the store through `@Bindable`; controllers
/// and services read it directly. Defaults are chosen so a fresh install
/// behaves exactly like v1 did.
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    /// Whether hovering or clicking opens the panel.
    var expandTrigger: ExpandTrigger {
        didSet { defaults.set(expandTrigger.rawValue, forKey: Keys.expandTrigger) }
    }

    /// How long the pointer must rest on the notch before a hover opens the
    /// panel. Zero matches v1: open immediately.
    var hoverDelayMilliseconds: Int {
        didSet { defaults.set(hoverDelayMilliseconds, forKey: Keys.hoverDelay) }
    }

    // MARK: - Feature flags

    /// Features the user turned off. Stored inverted so the default —
    /// an absent key — means everything is on.
    private var disabledFeatures: Set<String> {
        didSet {
            defaults.set(Array(disabledFeatures).sorted(), forKey: Keys.disabledFeatures)
        }
    }

    /// The composition root (AppDelegate) hooks this to start and stop the
    /// services behind a feature when its toggle flips at runtime.
    @ObservationIgnored var onFeatureChanged: ((FeatureID, Bool) -> Void)?

    func isEnabled(_ feature: FeatureID) -> Bool {
        !disabledFeatures.contains(feature.rawValue)
    }

    func setEnabled(_ feature: FeatureID, _ enabled: Bool) {
        guard enabled == disabledFeatures.contains(feature.rawValue) else { return }
        if enabled {
            disabledFeatures.remove(feature.rawValue)
        } else {
            disabledFeatures.insert(feature.rawValue)
        }
        onFeatureChanged?(feature, enabled)
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let expandTrigger = "settings.expandTrigger"
        static let hoverDelay = "settings.hoverDelayMilliseconds"
        static let disabledFeatures = "settings.disabledFeatures"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        expandTrigger =
            ExpandTrigger(rawValue: defaults.string(forKey: Keys.expandTrigger) ?? "")
            ?? .hover
        hoverDelayMilliseconds =
            defaults.object(forKey: Keys.hoverDelay) as? Int ?? 0
        disabledFeatures =
            Set(defaults.stringArray(forKey: Keys.disabledFeatures) ?? [])
    }
}
