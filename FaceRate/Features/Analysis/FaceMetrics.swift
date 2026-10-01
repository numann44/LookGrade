import CoreGraphics

/// Lightweight, Vision-framework-agnostic representation of a detected
/// face. Decouples `FaceScorer` from `VNFaceObservation` so the scoring
/// math is fully unit-testable without a real image/Vision request.
/// Field-for-field port of face_metrics.dart's `FaceMetrics`.
struct FaceMetrics {
    // The face bounding box, in image pixel coordinates.
    var boundingBox: CGRect
    // Full image dimensions; needed for normalization.
    var imageSize: CGSize

    // Single-point landmarks. Any may be nil if not detected.
    var leftEye: CGPoint? = nil
    var rightEye: CGPoint? = nil
    var noseBase: CGPoint? = nil
    var leftMouth: CGPoint? = nil
    var rightMouth: CGPoint? = nil
    var bottomMouth: CGPoint? = nil
    var leftCheek: CGPoint? = nil
    var rightCheek: CGPoint? = nil
    var leftEar: CGPoint? = nil
    var rightEar: CGPoint? = nil

    // Multi-point contours.
    var faceOval: [CGPoint] = []
    var leftEyeContour: [CGPoint] = []
    var rightEyeContour: [CGPoint] = []
    var upperLipTop: [CGPoint] = []
    var upperLipBottom: [CGPoint] = []
    var lowerLipTop: [CGPoint] = []
    var lowerLipBottom: [CGPoint] = []
    var noseBridge: [CGPoint] = []
    var noseBottom: [CGPoint] = []

    // Classifications (each in 0...1).
    var smilingProbability: Double = 0.5
    var leftEyeOpenProbability: Double = 0.9
    var rightEyeOpenProbability: Double = 0.9

    // Head pose, in degrees.
    var headEulerX: Double = 0
    var headEulerY: Double = 0
    var headEulerZ: Double = 0

    var faceWidth: Double { Double(boundingBox.width) }
    var faceHeight: Double { Double(boundingBox.height) }
    var faceCenter: CGPoint { CGPoint(x: boundingBox.midX, y: boundingBox.midY) }
}
