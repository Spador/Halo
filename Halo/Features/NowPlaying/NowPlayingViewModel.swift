import Foundation
import Observation

/// Presentation state for the Now Playing module. Views read `info`;
/// buttons call the intent methods, which forward to the service.
@Observable
final class NowPlayingViewModel {
    private(set) var info: NowPlayingInfo? {
        didSet { onInfoChanged?(info) }
    }

    /// The composition root feeds this into the live activity engine.
    @ObservationIgnored var onInfoChanged: ((NowPlayingInfo?) -> Void)?

    @ObservationIgnored private let service: NowPlayingService

    init(service: NowPlayingService = NowPlayingService()) {
        self.service = service
        service.onUpdate = { [weak self] info in
            self?.info = info
        }
    }

    /// Spawns the streaming helper. The composition root calls this only
    /// when the Now Playing feature is enabled.
    func start() {
        service.start()
    }

    /// Called on quit or feature toggle-off so the perl helper dies
    /// immediately instead of lingering until its next write fails.
    func shutdown() {
        service.stop()
        info = nil
    }

    func togglePlayPause() {
        service.send(.togglePlayPause)
        // Flip optimistically so the button reacts instantly; the stream
        // confirms (or corrects) a moment later.
        info?.isPlaying.toggle()
    }

    func nextTrack() { service.send(.nextTrack) }
    func previousTrack() { service.send(.previousTrack) }

    /// Likes/favorites the current track in the source app. Optimistic:
    /// the heart fills instantly, the stream confirms (or corrects).
    func toggleLike() {
        service.send(.likeTrack)
        info?.isLiked = !(info?.isLiked ?? false)
    }

    /// Jumps to an absolute position (progress bar drag). Optimistic like
    /// play/pause: the bar moves instantly, the stream confirms shortly.
    func seek(to seconds: TimeInterval) {
        service.seek(to: seconds)
        info?.elapsed = seconds
        info?.elapsedCapturedAt = Date()
    }
}
