import SwiftUI

/// The expanded-notch media card: artwork, track info, progress, controls.
struct NowPlayingView: View {
    let viewModel: NowPlayingViewModel
    let info: NowPlayingInfo

    /// While the user drags the bar, it follows the finger instead of
    /// playback; the seek fires once on release.
    @State private var isScrubbing = false
    @State private var scrubFraction: Double = 0

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
            let liveElapsed = info.estimatedElapsed(at: context.date)
            let fraction =
                isScrubbing ? scrubFraction : progressFraction(elapsed: liveElapsed)
            let shownElapsed =
                isScrubbing ? scrubFraction * (info.duration ?? 0) : liveElapsed
            HStack(spacing: 8) {
                Text(timeString(shownElapsed))
                progressBar(fraction: fraction)
                Text(timeString(info.duration))
            }
            .font(.system(size: 10).monospacedDigit())
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    /// The bar is draggable whenever the source reports a duration (without
    /// one there is no position to seek to).
    private func progressBar(fraction: Double) -> some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule()
                    .fill(.white)
                    .frame(width: max(fraction * width, 0))
            }
            // Negative inset: a 5pt bar is a mean drag target; accept
            // grabs from a few points above and below too.
            .contentShape(Rectangle().inset(by: -8))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard info.duration != nil else { return }
                        isScrubbing = true
                        scrubFraction = min(max(drag.location.x / width, 0), 1)
                    }
                    .onEnded { _ in
                        guard isScrubbing, let duration = info.duration else { return }
                        viewModel.seek(to: scrubFraction * duration)
                        isScrubbing = false
                    }
            )
        }
        .frame(height: 5)
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
