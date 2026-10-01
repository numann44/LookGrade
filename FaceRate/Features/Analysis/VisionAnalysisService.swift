import CoreGraphics
import UIKit
import Vision

/// Real on-device analysis using Apple's Vision framework. Produces
/// per-category scores from detected landmarks/contours plus pixel-level
/// skin sampling — the Vision-backed counterpart to
/// mlkit_analysis_service.dart's `MlKitAnalysisService`.
final class VisionAnalysisService: AnalysisService {
    private let sampler = SkinSampler()

    func analyze(_ input: ScanInput) async throws -> ScanResult {
        guard let cgImage = try loadCGImage(input) else {
            throw NoFaceDetectedError()
        }

        let request = VNDetectFaceLandmarksRequest()
        #if targetEnvironment(simulator)
        // Simulator has no iPhone Neural Engine. Use a supported CPU for
        // each stage while retaining real Vision detection and scoring.
        // Physical-device builds keep Apple's default accelerated selection.
        for (stage, devices) in try request.supportedComputeStageDevices {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        #endif
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            throw NoFaceDetectedError()
        }

        // Pick the largest face by bounding-box area.
        let face = observations.max {
            $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height
        }!

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
        let metrics = FaceMetrics.fromVision(face, imageSize: imageSize)
        let sample = await sampler.sample(metrics: metrics, image: cgImage)

        // Refuse to score inputs we can't actually read, with actionable
        // retake guidance, instead of silently returning a confident number
        // from mid-range fallbacks.
        try Self.checkQuality(face: face, metrics: metrics, sample: sample)

        let categories = FaceScorer.scoreAll(metrics, sample: sample)
        let overall = FaceScorer.overall(categories)
        // Potential delta: scaled by how far from a 9.5 ceiling.
        let potentialDelta = (min(max((9.5 - overall) * 0.45, 0.2), 1.0) * 10).rounded() / 10

        let findings = FindingsCatalog.build(from: categories)

        return ScanResult(
            input: input,
            overallScore: overall,
            potentialDelta: potentialDelta,
            categories: categories,
            findings: findings,
            faceShape: FaceProfile.faceShape(from: metrics),
            undertone: FaceProfile.undertone(from: sample)
        )
    }

    /// Conservative gates — only clearly-unreadable inputs are rejected, to
    /// avoid frustrating real users. Thresholds are lenient by design.
    private static func checkQuality(face: VNFaceObservation, metrics: FaceMetrics, sample: SkinSample?) throws {
        let boxArea = face.boundingBox.width * face.boundingBox.height
        if boxArea < 0.045 {
            throw ScanQualityError(NSLocalizedString("Your face looks far away. Move a little closer and retake.", comment: "scan quality"))
        }
        if abs(metrics.headEulerY) > 34 || abs(metrics.headEulerX) > 30 {
            throw ScanQualityError(NSLocalizedString("Face the camera straight on for an accurate read, then retake.", comment: "scan quality"))
        }
        if let sample {
            if sample.meanLuminance < 0.12 {
                throw ScanQualityError(NSLocalizedString("It's a bit dark. Find brighter, even lighting and retake.", comment: "scan quality"))
            }
            if sample.meanLuminance > 0.98 {
                throw ScanQualityError(NSLocalizedString("Too much glare. Reduce the light or move away from it, then retake.", comment: "scan quality"))
            }
        }
    }

    private func loadCGImage(_ input: ScanInput) throws -> CGImage? {
        guard !input.imagePath.isEmpty,
              let uiImage = UIImage(contentsOfFile: input.imagePath) else {
            return nil
        }
        // `UIImage(contentsOfFile:)` keeps the JPEG's EXIF orientation in
        // `imageOrientation`, but `.cgImage` hands back the raw sensor buffer
        // *without* applying it. Vision — and every downstream formula that
        // assumes an upright, top-left image ("chin = max Y", facial thirds,
        // the SkinSampler cheek rects) — would otherwise analyze a portrait
        // selfie rotated ~90°. Redraw upright so the whole pipeline shares one
        // correctly-oriented buffer.
        if uiImage.imageOrientation == .up, let cg = uiImage.cgImage {
            return cg
        }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)
        let normalized = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: uiImage.size))
        }
        return normalized.cgImage
    }

}
