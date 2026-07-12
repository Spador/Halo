import SwiftUI

/// Circular progress ring shared by the Timer and Pomodoro pages.
struct CompletionRing: View {
    /// 0 = just started, 1 = complete.
    var progress: Double
    var tint: Color
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.linear(duration: 1), value: progress)
    }
}
