import AVFoundation
import CoreMedia
import Foundation
import QuartzCore

enum CameraPermission {
    case granted, denied, permanentlyDenied, restricted, notSupported
}

enum CaptureError: LocalizedError {
    case noCamera
    case noImageData
    case notRunning
    case timedOut

    var errorDescription: String? {
        switch self {
        case .noCamera: return NSLocalizedString("No camera available on this device.", comment: "capture error")
        case .noImageData: return NSLocalizedString("Failed to capture image data.", comment: "capture error")
        case .notRunning: return NSLocalizedString("Camera isn't ready yet — give it a moment and try again.", comment: "capture error")
        case .timedOut: return NSLocalizedString("The camera didn't respond. Try again.", comment: "capture error")
        }
    }
}

/// Wraps `AVCaptureSession` so the rest of the app stays camera-API-agnostic.
/// All session configuration / start / stop runs on a private serial queue
/// (never the main thread), capture is guarded + timed out so the shutter
/// can't hang forever, and session interruptions (calls, Control Center) are
/// observed and auto-recovered. Front-camera-only.
final class CaptureService: NSObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let videoQueue = DispatchQueue(label: "com.facerate.camera.video")
    private var currentDevice: AVCaptureDevice?
    private var isConfigured = false
    private var lastFrameAt: CFTimeInterval = 0
    private let sessionQueue = DispatchQueue(label: "com.facerate.camera.session")

    /// Live capture-coaching signal (face framing + lighting), on the main
    /// actor. Drives the oval guide, lighting bars, hint text, auto-capture.
    var onFeedback: (@MainActor (CaptureFeedback) -> Void)?

    // Continuation access is guarded by `lock` because the capture callback
    // runs on an AVFoundation queue while the timeout fires on another —
    // `finish` guarantees the continuation resumes exactly once.
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ScanInput, Error>?
    private var timeoutItem: DispatchWorkItem?

    // Rotation handling (iOS 17+). `RotationCoordinator` tracks the physical
    // device orientation and hands back the exact `videoRotationAngle` that
    // keeps the preview and the captured photo horizon-level in *every*
    // orientation — replacing the old hard-coded 90° portrait assumption that
    // showed the feed sideways once iPad landscape / multitasking is allowed.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var previewRotationObservation: NSKeyValueObservation?
    private var captureRotationObservation: NSKeyValueObservation?
    private weak var previewLayer: AVCaptureVideoPreviewLayer?
    // Latest capture-connection angle; read off the capture thread so it's
    // guarded by `lock`. Defaults to portrait until the coordinator reports in.
    private var captureRotationAngle: CGFloat = 90

    /// Called on the main actor when the session is interrupted (`true`) or
    /// resumes (`false`), so the UI can show/hide a "camera paused" state.
    var onInterruptionChanged: (@MainActor (Bool) -> Void)?

    static var supportsLiveCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    func requestCameraPermission() async -> CameraPermission {
        guard Self.supportsLiveCamera else { return .notSupported }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .granted
        case .restricted:
            // Blocked by Screen Time / MDM — the user *can't* grant it in
            // Settings, so this is distinct from `.denied`.
            return .restricted
        case .denied:
            return .permanentlyDenied
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .granted : .denied
        @unknown default:
            return .denied
        }
    }

    /// Configures the front camera and starts the session, entirely off the
    /// main thread. Throws on failure — call sites handle it.
    func configureAndStart() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try self.configureLocked()
                    if !self.session.isRunning { self.session.startRunning() }
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    private func configureLocked() throws {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CaptureError.noCamera
        }
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .high
        if let existing = session.inputs.first { session.removeInput(existing) }
        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) { session.addInput(input) }
        currentDevice = device

        if !isConfigured {
            if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
            if session.canAddOutput(videoOutput) {
                videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                videoOutput.alwaysDiscardsLateVideoFrames = true
                videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
                session.addOutput(videoOutput)
            }
            isConfigured = true
            registerInterruptionObservers()
        }
        configurePhotoConnection()
    }

    /// The saved JPEG must match what the user framed: mirrored like the
    /// selfie preview, and rotated to the current orientation. Mirroring is
    /// orientation-independent so it's pinned here; the rotation angle is
    /// applied per-shot in `takePicture()` from the `RotationCoordinator`.
    private func configurePhotoConnection() {
        guard let connection = photoOutput.connection(with: .video) else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }

    // MARK: - Orientation

    /// Called on the main thread by `CameraPreviewView` once its preview layer
    /// exists. Wires up a `RotationCoordinator` that keeps both the live
    /// preview and the captured still level as the device rotates.
    func attachPreviewLayer(_ layer: AVCaptureVideoPreviewLayer) {
        previewLayer = layer
        guard let device = currentDevice else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: layer)
        rotationCoordinator = coordinator

        applyPreviewRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
        previewRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview, options: [.new]
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            self?.applyPreviewRotation(angle)
        }

        setCaptureRotation(coordinator.videoRotationAngleForHorizonLevelCapture)
        captureRotationObservation = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture, options: [.new]
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            self?.setCaptureRotation(angle)
        }
    }

    /// Applies a preview angle to the layer connection. Coordinator KVO fires
    /// on the main thread, matching the layer's threading requirements.
    private func applyPreviewRotation(_ angle: CGFloat) {
        guard let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }

    private func setCaptureRotation(_ angle: CGFloat) {
        lock.lock(); captureRotationAngle = angle; lock.unlock()
    }

    private func teardownRotationCoordinator() {
        previewRotationObservation?.invalidate()
        captureRotationObservation?.invalidate()
        previewRotationObservation = nil
        captureRotationObservation = nil
        rotationCoordinator = nil
        previewLayer = nil
    }

    func start() {
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    /// Captures a still and returns a `ScanInput` pointing at a stored JPEG.
    /// Guarded on a running session and bounded by a fail-safe timeout so a
    /// dropped delegate callback can't leave the shutter spinning forever.
    func takePicture() async throws -> ScanInput {
        guard session.isRunning else { throw CaptureError.notRunning }
        return try await withCheckedThrowingContinuation { cont in
            lock.lock()
            self.continuation = cont
            lock.unlock()

            let timeout = DispatchWorkItem { [weak self] in
                self?.finish(.failure(CaptureError.timedOut))
            }
            timeoutItem = timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 8, execute: timeout)

            // Level the still to the current orientation right before the shot.
            lock.lock(); let angle = captureRotationAngle; lock.unlock()
            if let connection = photoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }

            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    /// Resumes the capture continuation exactly once, whichever of the
    /// delegate callback / timeout gets there first.
    private func finish(_ result: Result<ScanInput, Error>) {
        lock.lock()
        guard let cont = continuation else { lock.unlock(); return }
        continuation = nil
        timeoutItem?.cancel()
        timeoutItem = nil
        lock.unlock()
        switch result {
        case .success(let value): cont.resume(returning: value)
        case .failure(let error): cont.resume(throwing: error)
        }
    }

    func dispose() {
        teardownRotationCoordinator()
        stop()
    }

    // MARK: - Interruption recovery

    private func registerInterruptionObservers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(sessionInterrupted), name: .AVCaptureSessionWasInterrupted, object: session)
        nc.addObserver(self, selector: #selector(sessionInterruptionEnded), name: .AVCaptureSessionInterruptionEnded, object: session)
        nc.addObserver(self, selector: #selector(sessionRuntimeError), name: .AVCaptureSessionRuntimeError, object: session)
    }

    @objc private func sessionInterrupted(_ note: Notification) {
        notifyInterruption(true)
    }

    @objc private func sessionInterruptionEnded(_ note: Notification) {
        start()
        notifyInterruption(false)
    }

    @objc private func sessionRuntimeError(_ note: Notification) {
        // A runtime error stops the session; attempt a single restart.
        start()
    }

    private func notifyInterruption(_ interrupted: Bool) {
        let callback = onInterruptionChanged
        Task { @MainActor in callback?(interrupted) }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension CaptureService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle to ~5 fps — enough for live coaching, cheap on battery.
        let now = CACurrentMediaTime()
        guard now - lastFrameAt > 0.2 else { return }
        lastFrameAt = now
        guard onFeedback != nil, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let luminance = FrameAnalyzer.meanLuminance(pixelBuffer)
        let faceRect = FrameAnalyzer.largestFaceRect(pixelBuffer)
        let feedback = CaptureFeedback.make(luminance: luminance, faceRect: faceRect)

        let callback = onFeedback
        Task { @MainActor in callback?(feedback) }
    }
}

extension CaptureService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            finish(.failure(error))
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            finish(.failure(CaptureError.noImageData))
            return
        }
        do {
            let url = try ScanImageStore.write(data)
            finish(.success(ScanInput(imagePath: url.path, capturedAt: Date(), source: .camera)))
        } catch {
            finish(.failure(error))
        }
    }
}
