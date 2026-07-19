import AVFoundation
import Observation

/// The capture session behind the mirror page. Strictly page-scoped: the
/// session starts when the mirror card appears and stops the moment it
/// disappears, so the camera light never lies about what Halo is doing.
/// Nothing is ever recorded — frames go to the preview layer and nowhere
/// else.
@Observable
final class CameraMirror {
    let session = AVCaptureSession()
    private(set) var isConfigured = false

    /// Session start/stop block, so they run off the main thread.
    @ObservationIgnored private let sessionQueue = DispatchQueue(
        label: "com.spador.Halo.camera"
    )

    func start() {
        guard PermissionsManager.shared.status(of: .camera) == .granted else { return }
        configureIfNeeded()
        guard isConfigured else { return }
        nonisolated(unsafe) let session = session
        sessionQueue.async {
            guard !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        nonisolated(unsafe) let session = session
        sessionQueue.async {
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else { return }
        session.beginConfiguration()
        session.sessionPreset = .high
        session.addInput(input)
        session.commitConfiguration()
        isConfigured = true
    }
}
