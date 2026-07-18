import SwiftUI

/// Persistent wing display for live activities, same geometry as the HUD
/// flash. One activity uses the wide layout (one wing each for its two
/// halves); two activities split the wings, one compact pair per side.
///
/// Media activities render as artwork plus equalizer; everything else as
/// icon plus text.
struct LiveActivityView: View {
    let items: [LiveActivityItem]
    let notchSize: CGSize
    let accent: Color

    var body: some View {
        HStack(spacing: 0) {
            leftWing
            Color.clear.frame(width: notchSize.width)
            rightWing
        }
        .frame(height: notchSize.height)
    }

    @ViewBuilder
    private var leftWing: some View {
        if let first = items.first {
            Group {
                if items.count == 1 {
                    if first.activity.isMedia {
                        artwork(first, size: 20)
                    } else {
                        Image(systemName: first.activity.iconName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tint(first))
                    }
                } else {
                    compact(first)
                }
            }
            .frame(width: NotchViewModel.hudWingWidth)
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        Group {
            if items.count > 1 {
                compact(items[1])
            } else if let first = items.first {
                if first.activity.isMedia {
                    // Wings animate while the notch is collapsed, so run
                    // at half the card's frame rate to stay near-free.
                    EqualizerBars(
                        isPlaying: true,
                        color: accent,
                        maxHeight: 13,
                        barWidth: 2.5,
                        framesPerSecond: 10
                    )
                } else {
                    Text(first.activity.text)
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(tint(first))
                }
            }
        }
        .frame(width: NotchViewModel.hudWingWidth)
    }

    @ViewBuilder
    private func compact(_ item: LiveActivityItem) -> some View {
        HStack(spacing: 4) {
            if item.activity.isMedia {
                artwork(item, size: 16)
                EqualizerBars(
                    isPlaying: true,
                    color: accent,
                    barCount: 3,
                    maxHeight: 10,
                    barWidth: 2,
                    framesPerSecond: 10
                )
            } else {
                Image(systemName: item.activity.iconName)
                    .font(.system(size: 10, weight: .semibold))
                Text(item.activity.text)
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(tint(item))
        .frame(width: NotchViewModel.hudWingWidth)
    }

    private func artwork(_ item: LiveActivityItem, size: CGFloat) -> some View {
        Group {
            if let image = item.activity.artwork {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: item.activity.iconName)
                    .font(.system(size: size * 0.55, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func tint(_ item: LiveActivityItem) -> Color {
        item.activity.emphasized ? .green : .white
    }
}
