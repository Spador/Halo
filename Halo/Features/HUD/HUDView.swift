import SwiftUI

/// The slim HUD drawn in the notch's "wings": icon in the strip left of
/// the camera housing, level bar in the strip to its right.
struct HUDView: View {
    let state: HUDState
    let notchSize: CGSize

    private let barWidth: CGFloat = 58

    /// Charging flashes green, low-battery warns red; volume and
    /// brightness stay white.
    private var tint: Color {
        switch state.kind {
        case .battery: .green
        case .batteryLow: .red
        case .volume, .brightness: .white
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: state.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: NotchViewModel.hudWingWidth)

            // The physical notch: nothing can be drawn here.
            Color.clear.frame(width: notchSize.width)

            levelBar
                .frame(width: NotchViewModel.hudWingWidth)
        }
        .frame(height: notchSize.height)
    }

    private var levelBar: some View {
        Capsule()
            .fill(.white.opacity(0.28))
            .frame(width: barWidth, height: 5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(tint)
                    .frame(width: barWidth * state.displayLevel)
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.85), value: state.displayLevel)
    }
}
