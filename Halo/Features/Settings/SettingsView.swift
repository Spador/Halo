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
        }
        .frame(width: 440)
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
