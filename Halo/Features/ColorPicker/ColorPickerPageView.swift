import SwiftUI

/// The color picker card: the system loupe on a button, and a grid of
/// recent picks. Click a swatch to copy its hex; right-click for formats.
struct ColorPickerPageView: View {
    let store: ColorPickerStore
    let settings: SettingsStore

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 8), count: 6
    )

    var body: some View {
        VStack(spacing: 12) {
            Button {
                store.pick()
            } label: {
                Label("Pick a color", systemImage: "eyedropper")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white.opacity(0.15)))
            }
            .buttonStyle(.plain)

            if store.swatches.isEmpty {
                Text("Picked colors stay here as swatches")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(store.swatches) { swatch in
                        swatchTile(swatch)
                    }
                }
                .padding(.horizontal, 24)
                Spacer(minLength: 0)
            }

            if let copied = store.lastCopied {
                Text("Copied \(copied)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(settings.accent.color)
            }
        }
        .padding(.vertical, 12)
    }

    private func swatchTile(_ swatch: Swatch) -> some View {
        Button {
            store.copy(swatch)
        } label: {
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(swatch.color)
                    .frame(height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                    )
                Text(swatch.hex)
                    .font(.system(size: 8).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Hex") { store.copy(swatch) }
            Button("Copy RGB") { store.copy(swatch, as: swatch.rgbText) }
            Divider()
            Button("Remove", role: .destructive) { store.remove(swatch) }
        }
    }
}
