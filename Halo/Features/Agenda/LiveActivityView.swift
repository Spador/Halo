import SwiftUI

/// Persistent wing display for live activities, same geometry as the HUD
/// flash. One activity uses the classic wide layout: icon in the left wing,
/// text in the right. Two activities split the wings, one compact
/// icon-plus-text pair on each side.
struct LiveActivityView: View {
    let items: [LiveActivityItem]
    let notchSize: CGSize

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
            if items.count == 1 {
                Image(systemName: first.activity.iconName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint(first))
                    .frame(width: NotchViewModel.hudWingWidth)
            } else {
                compact(first)
            }
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        if items.count > 1 {
            compact(items[1])
        } else if let first = items.first {
            Text(first.activity.text)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint(first))
                .frame(width: NotchViewModel.hudWingWidth)
        }
    }

    private func compact(_ item: LiveActivityItem) -> some View {
        HStack(spacing: 4) {
            Image(systemName: item.activity.iconName)
                .font(.system(size: 10, weight: .semibold))
            Text(item.activity.text)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(tint(item))
        .frame(width: NotchViewModel.hudWingWidth)
    }

    private func tint(_ item: LiveActivityItem) -> Color {
        item.activity.emphasized ? .green : .white
    }
}
