import SwiftUI

/// Pomodoro page: configurable durations when idle; while running, a
/// phase-colored completion ring, round dots, and pause/skip/reset.
struct PomodoroPageView: View {
    let engine: PomodoroEngine
    let settings: SettingsStore

    @State private var showingStats = false

    var body: some View {
        if showingStats {
            PomodoroStatsView(
                history: engine.history,
                settings: settings,
                onBack: { showingStats = false }
            )
        } else if let session = engine.session {
            running(session)
        } else {
            setup
        }
    }

    // MARK: - Idle: settings + start

    private var setup: some View {
        VStack(spacing: 14) {
            HStack(spacing: 22) {
                settingStepper(
                    "Focus", value: engine.settings.workMinutes,
                    decrease: { engine.settings.workMinutes = max(15, $0 - 5) },
                    increase: { engine.settings.workMinutes = min(60, $0 + 5) }
                )
                settingStepper(
                    "Break", value: engine.settings.breakMinutes,
                    decrease: { engine.settings.breakMinutes = max(3, $0 - 1) },
                    increase: { engine.settings.breakMinutes = min(15, $0 + 1) }
                )
                settingStepper(
                    "Long break", value: engine.settings.longBreakMinutes,
                    decrease: { engine.settings.longBreakMinutes = max(10, $0 - 5) },
                    increase: { engine.settings.longBreakMinutes = min(30, $0 + 5) }
                )
            }
            Text("Long break after every \(engine.settings.roundsPerSet) focus rounds")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
            HStack(spacing: 10) {
                Button("Start Pomodoro") { engine.start() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.white))
                Button {
                    showingStats = true
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Focus stats")
            }
        }
    }

    private func settingStepper(
        _ label: String,
        value: Int,
        decrease: @escaping (Int) -> Void,
        increase: @escaping (Int) -> Void
    ) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
            HStack(spacing: 7) {
                miniButton("minus") { decrease(value) }
                Text("\(value)m")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 34)
                miniButton("plus") { increase(value) }
            }
        }
    }

    // MARK: - Running: ring + rounds + controls

    private func running(_ session: PomodoroEngine.Session) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 30) {
                ZStack {
                    CompletionRing(
                        progress: session.progress(at: context.date),
                        tint: phaseColor(session.phase)
                    )
                    VStack(spacing: 2) {
                        Text(TimeText.string(session.remaining(at: context.date)))
                            .font(.system(size: 22, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                        Text(session.phase.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(phaseColor(session.phase))
                    }
                }
                .frame(width: 130, height: 130)

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 5) {
                        ForEach(1...engine.settings.roundsPerSet, id: \.self) { index in
                            Circle()
                                .fill(index <= completedRounds(session)
                                    ? phaseColor(.work)
                                    : .white.opacity(0.15))
                                .frame(width: 7, height: 7)
                        }
                        Text("round \(session.round)")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.45))
                            .padding(.leading, 4)
                    }
                    HStack(spacing: 8) {
                        miniButton(session.isPaused ? "play.fill" : "pause.fill") {
                            session.isPaused ? engine.resume() : engine.pause()
                        }
                        miniButton("forward.end.fill") { engine.skip() }
                        miniButton("stop.fill") { engine.reset() }
                    }
                }
            }
        }
    }

    /// Focus rounds finished in the current set: during a break the
    /// current round counts; mid-focus it doesn't yet.
    private func completedRounds(_ session: PomodoroEngine.Session) -> Int {
        session.phase == .work ? session.round - 1 : session.round
    }

    private func phaseColor(_ phase: PomodoroEngine.Phase) -> Color {
        switch phase {
        case .work: return .orange
        case .shortBreak: return .green
        case .longBreak: return .teal
        }
    }

    private func miniButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 30, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.12)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
