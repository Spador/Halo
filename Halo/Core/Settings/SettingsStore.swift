import Foundation
import Observation

/// How the panel opens when the pointer reaches the notch.
enum ExpandTrigger: String, CaseIterable, Identifiable {
    case hover
    case click

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hover: String(localized: "Hover")
        case .click: String(localized: "Click")
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

    // MARK: - Onboarding

    /// Set once the welcome tour has been finished, skipped, or closed —
    /// any of those means never show it automatically again.
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }

    /// Settings has a "show the welcome tour" button; the composition root
    /// owns the window, so the request travels through this hook.
    @ObservationIgnored var onReplayOnboardingRequested: (() -> Void)?

    func replayOnboarding() {
        onReplayOnboardingRequested?()
    }

    // MARK: - Appearance

    /// Accent for the expanded panel's tint and small highlights.
    var accent: ThemeAccent {
        didSet { defaults.set(accent.rawValue, forKey: Keys.accent) }
    }

    /// How strong the accent wash on the panel is; 0 is pure black,
    /// 1 matches the v1 look.
    var tintStrength: Double {
        didSet { defaults.set(tintStrength, forKey: Keys.tintStrength) }
    }

    /// Opacity of the expanded panel. 1 is the solid v1 look; lower lets
    /// what's behind the panel show through faintly.
    var panelOpacity: Double {
        didSet { defaults.set(panelOpacity, forKey: Keys.panelOpacity) }
    }

    // MARK: - Feature flags

    /// Explicit user choices only; an absent key means the feature's own
    /// registry default (most ship on, privacy-sensitive ones ship off).
    private var featureOverrides: [String: Bool] {
        didSet { defaults.set(featureOverrides, forKey: Keys.featureOverrides) }
    }

    /// The composition root (AppDelegate) hooks this to start and stop the
    /// services behind a feature when its toggle flips at runtime.
    @ObservationIgnored var onFeatureChanged: ((FeatureID, Bool) -> Void)?

    func isEnabled(_ feature: FeatureID) -> Bool {
        featureOverrides[feature.rawValue] ?? feature.enabledByDefault
    }

    func setEnabled(_ feature: FeatureID, _ enabled: Bool) {
        guard enabled != isEnabled(feature) else { return }
        featureOverrides[feature.rawValue] = enabled
        onFeatureChanged?(feature, enabled)
    }

    // MARK: - Global shortcuts

    /// Hotkey bindings keyed by `HotKeyAction` raw value. Empty by default:
    /// the user records combos in Settings.
    private var hotKeyBindings: [String: KeyCombo] {
        didSet {
            if let data = try? JSONEncoder().encode(hotKeyBindings) {
                defaults.set(data, forKey: Keys.hotKeys)
            }
            onHotKeysChanged?()
        }
    }

    /// The composition root re-registers all hotkeys when bindings change.
    @ObservationIgnored var onHotKeysChanged: (() -> Void)?

    /// True while a Settings recorder is armed; the composition root
    /// suspends hotkey registrations so the combo reaches the recorder.
    @ObservationIgnored var onHotKeyRecordingChanged: ((Bool) -> Void)?

    func setHotKeyRecording(_ active: Bool) {
        onHotKeyRecordingChanged?(active)
    }

    func binding(for action: HotKeyAction) -> KeyCombo? {
        hotKeyBindings[action.rawValue]
    }

    /// Assigns (or with nil, clears) an action's combo. A combo can serve
    /// only one action, so assigning steals it from any other action.
    func setBinding(_ combo: KeyCombo?, for action: HotKeyAction) {
        var updated = hotKeyBindings
        if let combo {
            for (key, existing) in updated where existing == combo {
                updated.removeValue(forKey: key)
            }
            updated[action.rawValue] = combo
        } else {
            updated.removeValue(forKey: action.rawValue)
        }
        hotKeyBindings = updated
    }

    /// The bindings in the typed form `HotKeyCenter.apply` wants.
    func typedHotKeyBindings() -> [HotKeyAction: KeyCombo] {
        hotKeyBindings.reduce(into: [:]) { result, entry in
            guard let action = HotKeyAction(rawValue: entry.key) else { return }
            result[action] = entry.value
        }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let expandTrigger = "settings.expandTrigger"
        static let hoverDelay = "settings.hoverDelayMilliseconds"
        static let accent = "settings.accent"
        static let tintStrength = "settings.tintStrength"
        static let panelOpacity = "settings.panelOpacity"
        static let disabledFeatures = "settings.disabledFeatures"  // legacy
        static let featureOverrides = "settings.featureOverrides"
        static let hotKeys = "settings.hotKeyBindings"
        static let onboarding = "settings.onboardingCompleted"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        expandTrigger =
            ExpandTrigger(rawValue: defaults.string(forKey: Keys.expandTrigger) ?? "")
            ?? .hover
        hoverDelayMilliseconds =
            defaults.object(forKey: Keys.hoverDelay) as? Int ?? 0
        accent =
            ThemeAccent(rawValue: defaults.string(forKey: Keys.accent) ?? "") ?? .teal
        tintStrength =
            defaults.object(forKey: Keys.tintStrength) as? Double ?? 1.0
        panelOpacity =
            defaults.object(forKey: Keys.panelOpacity) as? Double ?? 1.0
        var overrides =
            defaults.dictionary(forKey: Keys.featureOverrides) as? [String: Bool] ?? [:]
        // Migrate the v2.0 format (a plain list of disabled features).
        if let legacy = defaults.stringArray(forKey: Keys.disabledFeatures) {
            for raw in legacy { overrides[raw] = false }
            defaults.removeObject(forKey: Keys.disabledFeatures)
        }
        featureOverrides = overrides
        hotKeyBindings =
            defaults.data(forKey: Keys.hotKeys)
                .flatMap { try? JSONDecoder().decode([String: KeyCombo].self, from: $0) }
            ?? [:]
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
    }
}
