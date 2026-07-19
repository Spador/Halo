import AppKit

/// A snapshot of what the system is currently playing, from any source —
/// Apple Music, Spotify, or a browser tab.
struct NowPlayingInfo {
    var title: String
    var artist: String?
    var album: String?
    var isPlaying: Bool
    var artwork: NSImage?
    var appBundleID: String?

    /// Whether the source says the current track is liked/favorited, and
    /// whether it supports liking at all. Apple Music reports both; Spotify
    /// and browsers generally do not, which hides the heart button.
    var isLiked: Bool?
    var supportsLike: Bool = false

    /// Total track length in seconds, if the source reports one.
    var duration: TimeInterval?
    /// Elapsed playback time in seconds — but only as of `elapsedCapturedAt`.
    /// The stream doesn't tick every second (that would be polling); instead
    /// it tells us "playback was at 63.2s at 14:05:07" and we extrapolate.
    var elapsed: TimeInterval?
    var elapsedCapturedAt: Date?

    /// Best estimate of the elapsed time at `date`, extrapolated from the
    /// last update while playing, frozen while paused.
    func estimatedElapsed(at date: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        guard isPlaying, let elapsedCapturedAt else { return elapsed }
        let estimate = elapsed + date.timeIntervalSince(elapsedCapturedAt)
        if let duration { return min(estimate, duration) }
        return estimate
    }
}

/// Media commands the adapter can send, with MediaRemote's numeric IDs
/// (verified against Vendor/mediaremote-adapter/src/private/MediaRemote.h).
enum MediaCommand: Int {
    case play = 0
    case pause = 1
    case togglePlayPause = 2
    case nextTrack = 4
    case previousTrack = 5
    case likeTrack = 0x6A
}
