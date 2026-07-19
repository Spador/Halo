import AppKit

/// Bridges to the system's Now Playing state via the vendored
/// mediaremote-adapter (see Vendor/README.md for how and why).
///
/// One long-lived `/usr/bin/perl` process streams JSON lines to us —
/// entirely push-based, so Halo does zero work while nothing changes.
/// Commands (play/pause/skip) are short one-shot invocations of the same
/// script.
final class NowPlayingService {
    /// Called on every update. `nil` means nothing is playing.
    var onUpdate: (NowPlayingInfo?) -> Void = { _ in }

    private var streamProcess: Process?
    private var streamTask: Task<Void, Never>?
    private var restartAttempts = 0
    /// Distinguishes a deliberate stop (quit, feature toggled off) from the
    /// helper dying — only the latter should trigger the restart loop.
    private var intentionallyStopped = false
    private static let maxRestartAttempts = 5

    private let perlPath = "/usr/bin/perl"

    /// The adapter script and framework live inside the app bundle,
    /// placed there by the "Embed MediaRemoteAdapter" build phase.
    private var scriptURL: URL? {
        Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl")
    }
    private var frameworkURL: URL? {
        Bundle.main.privateFrameworksURL?
            .appendingPathComponent("MediaRemoteAdapter.framework")
    }

    func start() {
        guard streamProcess == nil else { return }
        intentionallyStopped = false
        guard let scriptURL, let frameworkURL else {
            assertionFailure("mediaremote-adapter resources missing from bundle")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: perlPath)
        process.arguments = [
            scriptURL.path,
            frameworkURL.path,
            "stream",
            "--micros",     // numeric microsecond timestamps, easier to parse
            "--no-diff",    // every update carries the full state
            "--debounce=100",
        ]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            onUpdate(nil)
            return
        }
        streamProcess = process

        // Read the stream line-by-line until the pipe closes (EOF), which
        // is also how we notice the helper died.
        streamTask = Task { [weak self] in
            var lines = stdout.fileHandleForReading.bytes.lines.makeAsyncIterator()
            while let line = try? await lines.next() {
                guard let self else { return }
                if case .nowPlaying(let info) = self.parse(line: line) {
                    self.restartAttempts = 0
                    self.onUpdate(info)
                }
            }
            self?.streamDidEnd()
        }
    }

    func stop() {
        intentionallyStopped = true
        streamTask?.cancel()
        streamTask = nil
        streamProcess?.terminate()
        streamProcess = nil
    }

    /// Fire-and-forget: a short perl invocation that sends one MediaRemote
    /// command and exits.
    func send(_ command: MediaCommand) {
        runOneShot(["send", String(command.rawValue)])
    }

    /// Jumps playback to an absolute position. The adapter's seek function
    /// takes microseconds.
    func seek(to seconds: TimeInterval) {
        runOneShot(["seek", String(Int64(seconds * 1_000_000))])
    }

    private func runOneShot(_ arguments: [String]) {
        guard let scriptURL, let frameworkURL else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: perlPath)
        process.arguments = [scriptURL.path, frameworkURL.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    /// If the helper dies (killed, or broken by an OS update), retry a few
    /// times with a pause, then give up gracefully: the UI just shows no
    /// media, the rest of Halo is unaffected.
    private func streamDidEnd() {
        streamProcess = nil
        streamTask = nil
        onUpdate(nil)

        guard !intentionallyStopped,
              restartAttempts < Self.maxRestartAttempts else { return }
        restartAttempts += 1
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.start()
        }
    }

    // MARK: - Stream parsing

    private enum StreamUpdate {
        case ignored
        case nowPlaying(NowPlayingInfo?)
    }

    /// One stream line looks like:
    /// `{"type":"data","diff":false,"payload":{"title":"...","playing":true,...}}`
    /// An empty payload means nothing is playing.
    private struct StreamEvent: Decodable {
        let type: String
        let payload: Payload?

        struct Payload: Decodable {
            var title: String?
            var artist: String?
            var album: String?
            var playing: Bool?
            var bundleIdentifier: String?
            var durationMicros: Int64?
            var elapsedTimeMicros: Int64?
            var timestampEpochMicros: Int64?
            var artworkData: String?
            var isLiked: Bool?
            var supportsIsLiked: Bool?
        }
    }

    private func parse(line: String) -> StreamUpdate {
        guard let data = line.data(using: .utf8),
              let event = try? JSONDecoder().decode(StreamEvent.self, from: data),
              event.type == "data"
        else { return .ignored }

        guard let payload = event.payload, let title = payload.title else {
            return .nowPlaying(nil)
        }

        var artwork: NSImage?
        if let base64 = payload.artworkData,
           let artworkBytes = Data(base64Encoded: base64) {
            artwork = NSImage(data: artworkBytes)
        }

        let micros = 1_000_000.0
        return .nowPlaying(NowPlayingInfo(
            title: title,
            artist: payload.artist,
            album: payload.album,
            isPlaying: payload.playing ?? false,
            artwork: artwork,
            appBundleID: payload.bundleIdentifier,
            isLiked: payload.isLiked,
            supportsLike: payload.supportsIsLiked ?? false,
            duration: payload.durationMicros.map { Double($0) / micros },
            elapsed: payload.elapsedTimeMicros.map { Double($0) / micros },
            elapsedCapturedAt: payload.timestampEpochMicros.map {
                Date(timeIntervalSince1970: Double($0) / micros)
            }
        ))
    }
}
