import SwiftUI

/// Persistent wing display for a running timer: icon in the left wing,
/// countdown in the right — same geometry as the HUD flash.
struct LiveActivityView: View {
    let activity: LiveActivity
    let notchSize: CGSize

    private var tint: Color {
        activity.emphasized ? .green : .white
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: activity.iconName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: NotchViewModel.hudWingWidth)

            Color.clear.frame(width: notchSize.width)

            Text(activity.text)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint)
                .frame(width: NotchViewModel.hudWingWidth)
        }
        .frame(height: notchSize.height)
    }
}
