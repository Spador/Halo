import AVFoundation
import SwiftUI

/// The mirror card: a flipped webcam preview for the seconds before a
/// call. Camera permission is requested here, on first use, never before.
struct MirrorPageView: View {
    let mirror: CameraMirror
    let settings: SettingsStore

    var body: some View {
        switch PermissionsManager.shared.status(of: .camera) {
        case .granted:
            CameraPreview(session: mirror.session)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .onAppear { mirror.start() }
                .onDisappear { mirror.stop() }

        case .notDetermined:
            VStack(spacing: 8) {
                Image(systemName: "web.camera")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.white.opacity(0.6))
                Button("Enable the mirror") {
                    PermissionsManager.shared.request(.camera) { _ in }
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.15)))
                Text("The camera runs only while this page is open. Nothing is recorded.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }

        case .denied:
            VStack(spacing: 8) {
                Text("Camera access denied. Enable it in System Settings to use the mirror.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Open System Settings") {
                    PermissionsManager.shared.openSystemSettings(for: .camera)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}

/// AppKit host for the AVCapture preview layer, flipped horizontally so
/// it reads as a mirror rather than a camera.
private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        if let connection = preview.connection {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        preview.frame = view.bounds
        preview.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = preview
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
