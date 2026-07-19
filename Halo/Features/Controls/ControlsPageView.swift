import SwiftUI

/// The control sliders card: volume and brightness by mouse instead of
/// keys. Future controls (output device picker) join this page.
struct ControlsPageView: View {
    let viewModel: ControlsViewModel
    let settings: SettingsStore

    var body: some View {
        VStack(spacing: 20) {
            slider(
                icon: "speaker.wave.2.fill",
                level: viewModel.volumeLevel,
                available: viewModel.volumeAvailable,
                unavailableHint: String(localized: "This output has no volume control"),
                onChange: { viewModel.setVolume($0) }
            )
            slider(
                icon: "sun.max.fill",
                level: viewModel.brightnessLevel,
                available: viewModel.brightnessAvailable,
                unavailableHint: String(localized: "No built-in display to control"),
                onChange: { viewModel.setBrightness($0) }
            )
            outputPicker
        }
        .padding(.horizontal, 44)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { viewModel.refresh() }
    }

    /// The output destination list, refreshed each time the card opens.
    private var outputPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Output")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            ScrollView(showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(viewModel.outputDevices) { device in
                        outputRow(device)
                    }
                }
            }
            .frame(maxHeight: 78)
        }
    }

    private func outputRow(_ device: AudioOutputDevice) -> some View {
        let isCurrent = device.id == viewModel.currentOutputID
        return Button {
            viewModel.selectOutput(device)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: device.iconName)
                    .font(.system(size: 11))
                    .frame(width: 18)
                Text(device.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(settings.accent.color)
                }
            }
            .foregroundStyle(.white.opacity(isCurrent ? 0.95 : 0.6))
            .padding(.horizontal, 8)
            .frame(height: 24)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.white.opacity(isCurrent ? 0.08 : 0))
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func slider(
        icon: String,
        level: Double,
        available: Bool,
        unavailableHint: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(available ? 0.85 : 0.3))
                .frame(width: 26)

            if available {
                NotchSlider(
                    level: level,
                    accent: settings.accent.color,
                    onChange: onChange
                )
                Text("\(Int(level * 100))%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 42, alignment: .trailing)
            } else {
                Text(unavailableHint)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// A capsule slider tuned for the dark panel: click or drag anywhere on the
/// track to set the level directly.
private struct NotchSlider: View {
    let level: Double
    let accent: Color
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                Capsule()
                    .fill(accent)
                    .frame(width: max(level * width, 0))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        onChange(min(max(drag.location.x / width, 0), 1))
                    }
            )
        }
        .frame(height: 8)
        .animation(.linear(duration: 0.08), value: level)
    }
}
