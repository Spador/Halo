import SwiftUI

/// The Settings window content. Lives inside the standard `Settings` scene,
/// so macOS provides the window, Cmd-comma shortcut, and menu item for free.
/// More tabs join the `TabView` as v2 features land.
struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            featuresTab
                .tabItem { Label("Features", systemImage: "switch.2") }
        }
        .frame(width: 440)
    }

    /// One toggle per module, straight off the `FeatureID` registry.
    private var featuresTab: some View {
        Form {
            ForEach(FeatureID.allCases) { feature in
                Toggle(isOn: binding(for: feature)) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.label)
                            Text(feature.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: feature.symbol)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Routes through `setEnabled` so the store can notify the composition
    /// root to start or stop the services behind the feature.
    private func binding(for feature: FeatureID) -> Binding<Bool> {
        Binding(
            get: { settings.isEnabled(feature) },
            set: { settings.setEnabled(feature, $0) }
        )
    }

    private var generalTab: some View {
        Form {
            Section("Opening the notch") {
                Picker("Open on", selection: $settings.expandTrigger) {
                    ForEach(ExpandTrigger.allCases) { trigger in
                        Text(trigger.label).tag(trigger)
                    }
                }
                .pickerStyle(.segmented)

                if settings.expandTrigger == .hover {
                    LabeledContent("Hover delay") {
                        Slider(value: hoverDelay, in: 0...1000, step: 50) {
                            Text("Hover delay")
                        }
                        Text("\(settings.hoverDelayMilliseconds) ms")
                            .monospacedDigit()
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch Halo at login", isOn: launchAtLoginBinding)
                if let error = launchAtLogin.lastError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Slider wants a Double; the store keeps whole milliseconds.
    private var hoverDelay: Binding<Double> {
        Binding(
            get: { Double(settings.hoverDelayMilliseconds) },
            set: { settings.hoverDelayMilliseconds = Int($0) }
        )
    }

    /// The system owns launch-at-login state, so the toggle routes through
    /// `setEnabled` rather than binding to the property directly.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        )
    }
}
