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
            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            permissionsTab
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .frame(width: 440)
    }

    private var shortcutsTab: some View {
        Form {
            Section {
                ForEach(HotKeyAction.allCases) { action in
                    LabeledContent(action.label) {
                        HStack(spacing: 6) {
                            ShortcutRecorder(action: action, settings: settings)
                            Button {
                                settings.setBinding(nil, for: action)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Remove this shortcut")
                            // Hidden instead of absent keeps rows aligned.
                            .opacity(settings.binding(for: action) == nil ? 0 : 1)
                            .disabled(settings.binding(for: action) == nil)
                        }
                    }
                }
            } footer: {
                Text("Shortcuts work from any app. Click a button, then press a combination that includes Command, Control, or Option. Escape cancels a recording; the x removes a shortcut.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    /// Live status of every macOS permission Halo can use, with the reason
    /// it wants each one. Requests still happen at first feature use; this
    /// tab is for seeing and fixing the state, not for asking early.
    private var permissionsTab: some View {
        Form {
            ForEach(Permission.allCases) { permission in
                Section {
                    LabeledContent {
                        statusText(PermissionsManager.shared.status(of: permission))
                    } label: {
                        Label(permission.label, systemImage: permission.symbol)
                    }
                    Text(permission.explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Open System Settings") {
                        PermissionsManager.shared.openSystemSettings(for: permission)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { PermissionsManager.shared.refresh() }
    }

    private func statusText(_ status: PermissionStatus) -> Text {
        switch status {
        case .granted: Text("Granted").foregroundStyle(.green)
        case .denied: Text("Not granted").foregroundStyle(.orange)
        case .notDetermined: Text("Not asked yet").foregroundStyle(.secondary)
        }
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

            Section("Appearance") {
                Picker("Accent color", selection: $settings.accent) {
                    ForEach(ThemeAccent.allCases) { accent in
                        HStack {
                            Circle().fill(accent.color).frame(width: 10, height: 10)
                            Text(accent.label)
                        }
                        .tag(accent)
                    }
                }

                LabeledContent("Panel tint") {
                    Slider(value: $settings.tintStrength, in: 0...1) {
                        Text("Panel tint")
                    }
                    Text("\(Int(settings.tintStrength * 100))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                }

                LabeledContent("Panel opacity") {
                    Slider(value: $settings.panelOpacity, in: 0.75...1) {
                        Text("Panel opacity")
                    }
                    Text("\(Int(settings.panelOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
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

            Section {
                Button("Show the welcome tour") {
                    settings.replayOnboarding()
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
