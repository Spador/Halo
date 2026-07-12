import SwiftUI

/// Timer page: preset and custom durations when idle, a completion ring
/// with controls while counting down.
struct TimerPageView: View {
    let engine: QuickTimerEngine

    @State private var customMinutes = 15

    var body: some View {
        if let countdown = engine.countdown {
            running(countdown)
        } else {
            picker
        }
    }

    // MARK: - Idle: duration picker

    private var picker: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                ForEach([5, 10, 15, 20, 30], id: \.self) { minutes in
                    Button("\(minutes)m") { engine.start(minutes: minutes) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 30)
                        .background(Capsule().fill(.white.opacity(0.12)))
                }
            }
            HStack(spacing: 10) {
                stepButton("minus") { customMinutes = max(1, customMinutes - 1) }
                Text("\(customMinutes) min")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 64)
                stepButton("plus") { customMinutes = min(120, customMinutes + 1) }
                Button("Start") { engine.start(minutes: customMinutes) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.white))
            }
        }
    }

    // MARK: - Running: ring + controls

    private func running(_ countdown: QuickTimerEngine.Countdown) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 30) {
                ZStack {
                    CompletionRing(
                        progress: countdown.progress(at: context.date),
                        tint: .white
                    )
                    VStack(spacing: 2) {
                        Text(TimeText.string(countdown.remaining(at: context.date)))
                            .font(.system(size: 22, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                        Text("of \(Int(countdown.totalSeconds / 60)) min")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .frame(width: 130, height: 130)

                VStack(spacing: 12) {
                    controlButton(
                        countdown.isPaused ? "play.fill" : "pause.fill",
                        label: countdown.isPaused ? "Resume" : "Pause"
                    ) {
                        countdown.isPaused ? engine.resume() : engine.pause()
                    }
                    controlButton("xmark", label: "Cancel") { engine.cancel() }
                }
            }
        }
    }

    // MARK: - Pieces

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 26, height: 26)
                .background(Circle().fill(.white.opacity(0.12)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func controlButton(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 10, weight: .bold))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 92, height: 28)
            .background(Capsule().fill(.white.opacity(0.12)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
