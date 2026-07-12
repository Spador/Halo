import SwiftUI

/// The expanded-notch media card: artwork, track info, progress, controls.
struct NowPlayingView: View {
    let viewModel: NowPlayingViewModel
    let info: NowPlayingInfo

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                artworkView
                VStack(alignment: .leading, spacing: 3) {
                    Text(info.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let artist = info.artist {
                        Text(artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }

            progressView

            HStack(spacing: 28) {
                controlButton("backward.fill") { viewModel.previousTrack() }
                controlButton(info.isPlaying ? "pause.fill" : "play.fill", size: 22) {
                    viewModel.togglePlayPause()
                }
                controlButton("forward.fill") { viewModel.nextTrack() }
            }
        }
        .padding(.horizontal, 22)
    }

    private var artworkView: some View {
        Group {
            if let artwork = info.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.1))
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.white.opacity(0.4))
                    }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// TimelineView redraws the bar every half-second — but only while this
    /// view exists, i.e. only while the notch is expanded. Collapsed = zero
    /// timers, zero work.
    private var progressView: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = info.estimatedElapsed(at: context.date)
            HStack(spacing: 8) {
                Text(timeString(elapsed))
                ProgressView(value: progressFraction(elapsed: elapsed))
                    .progressViewStyle(.linear)
                    .tint(.white)
                Text(timeString(info.duration))
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private func progressFraction(elapsed: TimeInterval?) -> Double {
        guard let elapsed, let duration = info.duration, duration > 0 else { return 0 }
        return min(max(elapsed / duration, 0), 1)
    }

    private func timeString(_ interval: TimeInterval?) -> String {
        guard let interval, interval.isFinite else { return "–:––" }
        let total = Int(interval)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func controlButton(
        _ symbol: String,
        size: CGFloat = 16,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
