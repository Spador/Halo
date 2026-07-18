import SwiftUI

/// The control sliders card: volume and brightness by mouse instead of
/// keys. Future controls (output device picker) join this page.
struct ControlsPageView: View {
    let viewModel: ControlsViewModel
    let settings: SettingsStore

    var body: some View {
        VStack(spacing: 30) {
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
        }
        .padding(.horizontal, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { viewModel.refresh() }
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
