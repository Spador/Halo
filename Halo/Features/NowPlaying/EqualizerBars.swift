import SwiftUI

/// Animated equalizer bars: dancing while playing, resting low when paused.
///
/// Purely decorative. Analyzing the real audio would need a capture
/// permission and constant CPU, so the motion is a smooth pseudo-random
/// function of time — two out-of-phase sine waves per bar, which reads as
/// organic bounce. The TimelineView only ticks while the view is on screen
/// and playback is running; otherwise this costs nothing.
struct EqualizerBars: View {
    var isPlaying: Bool
    var color: Color = .white
    var barCount: Int = 4
    var maxHeight: CGFloat = 16
    var barWidth: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: barWidth * 0.8) {
                ForEach(0..<barCount, id: \.self) { bar in
                    Capsule()
                        .fill(color)
                        .frame(
                            width: barWidth,
                            height: maxHeight * (isPlaying ? level(bar: bar, time: time) : 0.25)
                        )
                }
            }
            .frame(height: maxHeight, alignment: .bottom)
            .animation(.linear(duration: 0.05), value: isPlaying)
        }
    }

    /// 0.2...1.0, different rhythm per bar so they never move in lockstep.
    private func level(bar: Int, time: Double) -> Double {
        let phase = Double(bar) * 1.7
        let a = sin(time * (3.1 + Double(bar) * 0.6) + phase)
        let b = sin(time * (5.3 - Double(bar) * 0.4) + phase * 2)
        return 0.2 + 0.8 * (0.5 + 0.25 * a + 0.25 * b)
    }
}
