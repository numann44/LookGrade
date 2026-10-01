import CoreGraphics
import Vision

/// Adapter from Apple's Vision framework to the plugin-agnostic
/// `FaceMetrics` shape — the Vision-side counterpart to
/// mlkit_analysis_service.dart's ML-Kit adapter.
///
/// Vision reports everything normalized with a BOTTOM-LEFT origin
/// (0 = left/bottom, 1 = right/top); FaceMetrics uses image PIXEL
/// coordinates with a TOP-LEFT origin (matching ML Kit's convention, which
/// `face_scorer.dart`'s formulas were written against — e.g. "chin = max
/// dy"). Every point below goes through `toPixel`/`toPixelRect`, which does
/// both the bounding-box-relative -> whole-image conversion AND the Y flip.
extension FaceMetrics {
    static func fromVision(_ face: VNFaceObservation, imageSize: CGSize) -> FaceMetrics {
        let bb = toPixelRect(face.boundingBox, imageSize: imageSize)
        let landmarks = face.landmarks

        func points(_ landmarkRegion: VNFaceLandmarkRegion2D?) -> [CGPoint] {
            guard let landmarkRegion else { return [] }
            return landmarkRegion.normalizedPoints.map {
                toPixel($0, boundingBox: face.boundingBox, imageSize: imageSize)
            }
        }

        func singlePoint(_ landmarkRegion: VNFaceLandmarkRegion2D?) -> CGPoint? {
            let pts = points(landmarkRegion)
            guard !pts.isEmpty else { return nil }
            return FaceGeo.centroid(pts)
        }

        let faceOval = points(landmarks?.faceContour)
        let leftEyeContour = points(landmarks?.leftEye)
        let rightEyeContour = points(landmarks?.rightEye)
        let noseBridge = points(landmarks?.noseCrest)
        let noseBottom = points(landmarks?.nose)
        let outerLips = points(landmarks?.outerLips)
        let innerLips = points(landmarks?.innerLips)

        // Vision gives one closed outer/inner lip contour rather than ML
        // Kit's 4-way top/bottom split. Bucket by vertical half instead —
        // `scoreLips` only ever consumes upperLipTop+upperLipBottom and
        // lowerLipTop+lowerLipBottom as two combined point sets, so this
        // preserves the math even though the sub-split isn't identical.
        let mouthMidY = FaceGeo.centroid(outerLips).y
        let upperOuter = outerLips.filter { $0.y < mouthMidY }
        let lowerOuter = outerLips.filter { $0.y >= mouthMidY }
        let upperInner = innerLips.filter { $0.y < mouthMidY }
        let lowerInner = innerLips.filter { $0.y >= mouthMidY }

        let leftEyePoint = singlePoint(landmarks?.leftPupil) ?? singlePoint(landmarks?.leftEye)
        let rightEyePoint = singlePoint(landmarks?.rightPupil) ?? singlePoint(landmarks?.rightEye)
        let leftMouth = outerLips.min { $0.x < $1.x }
        let rightMouth = outerLips.max { $0.x < $1.x }
        let bottomMouth = outerLips.max { $0.y < $1.y }
        let noseBase = noseBottom.isEmpty ? nil : FaceGeo.centroid(noseBottom)

        return FaceMetrics(
            boundingBox: bb,
            imageSize: imageSize,
            leftEye: leftEyePoint,
            rightEye: rightEyePoint,
            noseBase: noseBase,
            leftMouth: leftMouth,
            rightMouth: rightMouth,
            bottomMouth: bottomMouth,
            leftCheek: nil,  // Vision has no cheek landmark — SkinSampler's
            rightCheek: nil, // face-box-relative fallback is the primary path.
            leftEar: nil,    // Never read by FaceScorer (unused in the Dart original too).
            rightEar: nil,
            faceOval: faceOval,
            leftEyeContour: leftEyeContour,
            rightEyeContour: rightEyeContour,
            upperLipTop: upperOuter,
            upperLipBottom: upperInner,
            lowerLipTop: lowerOuter,
            lowerLipBottom: lowerInner,
            noseBridge: noseBridge,
            noseBottom: noseBottom,
            smilingProbability: estimateSmiling(outerLips: outerLips, innerLips: innerLips),
            leftEyeOpenProbability: estimateEyeOpenness(leftEyeContour),
            rightEyeOpenProbability: estimateEyeOpenness(rightEyeContour),
            headEulerX: face.pitch.map { Double(truncating: $0) * 180 / .pi } ?? 0,
            headEulerY: face.yaw.map { Double(truncating: $0) * 180 / .pi } ?? 0,
            headEulerZ: face.roll.map { Double(truncating: $0) * 180 / .pi } ?? 0
        )
    }

    /// Vision has no eye-open classification like ML Kit — new heuristic:
    /// eye-aspect-ratio (vertical span / horizontal span of the eye
    /// contour), mapped onto roughly the same 0...1 range ML Kit's
    /// probability occupies. Needs tuning against real photos (see the
    /// migration plan's flagged risks) — this is a starting point, not a
    /// port of anything.
    private static func estimateEyeOpenness(_ contour: [CGPoint]) -> Double {
        guard contour.count >= 4, let box = FaceGeo.bbox(of: contour), box.width > 0 else { return 0.9 }
        let ear = Double(box.height / box.width)
        return min(max((ear - 0.05) / (0.30 - 0.05), 0), 1)
    }

    /// New heuristic (Vision has no smile classification): wider/flatter
    /// outer-lip bounding box relative to the gap between outer and inner
    /// contours reads as more "smiling". Approximate; tune against real
    /// photos.
    private static func estimateSmiling(outerLips: [CGPoint], innerLips: [CGPoint]) -> Double {
        guard let outerBox = FaceGeo.bbox(of: outerLips), outerBox.width > 0 else { return 0.5 }
        let widthToHeight = Double(outerBox.width / max(outerBox.height, 1))
        return min(max((widthToHeight - 2.0) / (5.0 - 2.0), 0), 1)
    }

    private static func toPixel(_ normalizedInBoundingBox: CGPoint, boundingBox: CGRect, imageSize: CGSize) -> CGPoint {
        let normX = boundingBox.origin.x + normalizedInBoundingBox.x * boundingBox.width
        let normY = boundingBox.origin.y + normalizedInBoundingBox.y * boundingBox.height
        return CGPoint(x: normX * imageSize.width, y: (1 - normY) * imageSize.height)
    }

    private static func toPixelRect(_ normalized: CGRect, imageSize: CGSize) -> CGRect {
        let x = normalized.origin.x * imageSize.width
        let width = normalized.width * imageSize.width
        let height = normalized.height * imageSize.height
        let y = (1 - normalized.origin.y - normalized.height) * imageSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
