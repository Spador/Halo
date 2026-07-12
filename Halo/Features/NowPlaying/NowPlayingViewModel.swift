import Observation

/// Presentation state for the Now Playing module. Views read `info`;
/// buttons call the intent methods, which forward to the service.
@Observable
final class NowPlayingViewModel {
    private(set) var info: NowPlayingInfo?

    @ObservationIgnored private let service: NowPlayingService

    init(service: NowPlayingService = NowPlayingService()) {
        self.service = service
        service.onUpdate = { [weak self] info in
            self?.info = info
        }
        service.start()
    }

    /// Called when the app quits so the perl helper dies immediately
    /// instead of lingering until its next write fails.
    func shutdown() {
        service.stop()
    }

    func togglePlayPause() {
        service.send(.togglePlayPause)
        // Flip optimistically so the button reacts instantly; the stream
        // confirms (or corrects) a moment later.
        info?.isPlaying.toggle()
    }

    func nextTrack() { service.send(.nextTrack) }
    func previousTrack() { service.send(.previousTrack) }
}
