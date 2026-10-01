import AVFoundation
import SwiftUI

/// Full-screen live camera preview, mirrored to match a front-camera selfie
/// feel. Rotation is driven by the service's `RotationCoordinator` (set up in
/// `attachPreviewLayer`) so the feed stays level in every orientation,
/// including iPad landscape and multitasking.
struct CameraPreviewView: UIViewRepresentable {
    let service: CaptureService

    func makeUIView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.videoPreviewLayer.session = service.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection,
           connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        service.attachPreviewLayer(view.videoPreviewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {}
}

final class PreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
