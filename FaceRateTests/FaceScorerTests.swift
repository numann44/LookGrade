import XCTest
import CoreGraphics
@testable import FaceRate

/// Port of test/analysis/face_scorer_test.dart. Mirrors its exact
/// assertions: band membership + relative perturbation direction, NOT
/// golden numbers — the Dart original pins no exact score for any input,
/// so bit-exact parity isn't the bar; reproducing the same band membership
/// and the same direction of movement under perturbation is.
final class FaceScorerTests: XCTestCase {
    /// A perfectly symmetric synthetic bust at 1080x1920 with reasonable
    /// proportions, ported field-for-field from the Dart test's
    /// `buildIdealMetrics()`.
    private func buildIdealMetrics() -> FaceMetrics {
        let imageSize = CGSize(width: 1080, height: 1920)
        let faceLeft = 216.0, faceTop = 192.0, faceWidth = 648.0, faceHeight = 1536.0
        let box = CGRect(x: faceLeft, y: faceTop, width: faceWidth, height: faceHeight)
        let cx = Double(box.midX)

        var oval: [CGPoint] = []
        for i in 0..<24 {
            let t = Double(i) / 23.0
            let a = (t * 2 - 1) * 1.2
            let x = cx + a * faceWidth / 2 * 0.95
            let y = faceTop + (1 - abs(1 - t * 2) * 0.1) * faceHeight
            oval.append(CGPoint(x: x, y: y))
        }

        func eyeContour(centerX: Double, centerY: Double) -> [CGPoint] {
            (0..<8).map { i in
                let t = Double(i) / 7.0 * 2 * Double.pi
                let eyeW = 130.0, eyeH = 50.0
                return CGPoint(x: centerX + (eyeW / 2) * cos(t), y: centerY + (eyeH / 2) * sin(t))
            }
        }

        let leftEye = CGPoint(x: cx - 160, y: faceTop + faceHeight * 0.40)
        let rightEye = CGPoint(x: cx + 160, y: faceTop + faceHeight * 0.40)
        let leftEyeContour = eyeContour(centerX: Double(leftEye.x), centerY: Double(leftEye.y))
        let rightEyeContour = eyeContour(centerX: Double(rightEye.x), centerY: Double(rightEye.y))

        let mouthY = faceTop + faceHeight * 0.78
        var lipPts: [CGPoint] = []
        for i in 0..<8 {
            let t = Double(i) / 7.0
            let x = cx + (t - 0.5) * faceWidth * 0.46
            lipPts.append(CGPoint(x: x, y: mouthY - 12))
        }
        var lowerLipBottom: [CGPoint] = []
        for i in 0..<8 {
            let t = Double(i) / 7.0
            let x = cx + (t - 0.5) * faceWidth * 0.46
            lowerLipBottom.append(CGPoint(x: x, y: mouthY + 12))
        }

        let noseBridge = (0..<6).map { i in
            CGPoint(x: cx, y: faceTop + faceHeight * (0.40 + Double(i) * 0.025))
        }
        let noseBottom = (0..<6).map { i -> CGPoint in
            let x = cx + (Double(i) / 5.0 - 0.5) * faceWidth * 0.27
            return CGPoint(x: x, y: faceTop + faceHeight * 0.62)
        }

        return FaceMetrics(
            boundingBox: box,
            imageSize: imageSize,
            leftEye: leftEye,
            rightEye: rightEye,
            noseBase: CGPoint(x: cx, y: faceTop + faceHeight * 0.60),
            leftMouth: CGPoint(x: cx - faceWidth * 0.23, y: mouthY),
            rightMouth: CGPoint(x: cx + faceWidth * 0.23, y: mouthY),
            bottomMouth: CGPoint(x: cx, y: mouthY + 14),
            leftCheek: CGPoint(x: cx - faceWidth * 0.30, y: faceTop + faceHeight * 0.55),
            rightCheek: CGPoint(x: cx + faceWidth * 0.30, y: faceTop + faceHeight * 0.55),
            faceOval: oval,
            leftEyeContour: leftEyeContour,
            rightEyeContour: rightEyeContour,
            upperLipTop: lipPts,
            upperLipBottom: lipPts,
            lowerLipTop: lowerLipBottom,
            lowerLipBottom: lowerLipBottom,
            noseBridge: noseBridge,
            noseBottom: noseBottom,
            smilingProbability: 0.6,
            leftEyeOpenProbability: 0.95,
            rightEyeOpenProbability: 0.95,
            headEulerX: 0,
            headEulerY: 0,
            headEulerZ: 0
        )
    }

    func testIdealMetricsYieldHighScoresAcrossAllCategories() {
        let m = buildIdealMetrics()
        let scores = FaceScorer.scoreAll(m)
        XCTAssertEqual(scores.count, 8)
        for cs in scores {
            XCTAssertTrue((5.5...9.5).contains(cs.value), "\(cs.category.label) = \(cs.value)")
        }
        let highCount = scores.filter { $0.value >= 7.0 }.count
        XCTAssertGreaterThanOrEqual(highCount, 5)
    }

    func testOverallIsWeightedMeanWithinTheSameBand() {
        let m = buildIdealMetrics()
        let scores = FaceScorer.scoreAll(m)
        let overall = FaceScorer.overall(scores)
        XCTAssertTrue((5.5...9.5).contains(overall))
        let mean = scores.map(\.value).reduce(0, +) / Double(scores.count)
        XCTAssertLessThan(abs(overall - mean), 0.5)
    }

    func testLargeHeadYawDropsSymmetryScore() {
        let ideal = buildIdealMetrics()
        var asym = FaceMetrics(boundingBox: ideal.boundingBox, imageSize: ideal.imageSize)
        asym.leftEye = ideal.leftEye.map { CGPoint(x: $0.x + 40, y: $0.y) }
        asym.rightEye = ideal.rightEye
        asym.leftMouth = ideal.leftMouth.map { CGPoint(x: $0.x + 40, y: $0.y) }
        asym.rightMouth = ideal.rightMouth
        asym.bottomMouth = ideal.bottomMouth
        asym.leftCheek = ideal.leftCheek
        asym.rightCheek = ideal.rightCheek
        asym.noseBase = ideal.noseBase
        asym.faceOval = ideal.faceOval
        asym.leftEyeContour = ideal.leftEyeContour
        asym.rightEyeContour = ideal.rightEyeContour
        asym.upperLipTop = ideal.upperLipTop
        asym.upperLipBottom = ideal.upperLipBottom
        asym.lowerLipTop = ideal.lowerLipTop
        asym.lowerLipBottom = ideal.lowerLipBottom
        asym.noseBridge = ideal.noseBridge
        asym.noseBottom = ideal.noseBottom
        asym.smilingProbability = ideal.smilingProbability
        asym.leftEyeOpenProbability = ideal.leftEyeOpenProbability
        asym.rightEyeOpenProbability = ideal.rightEyeOpenProbability
        asym.headEulerY = 18 // large yaw

        let idealSym = FaceScorer.scoreSymmetry(ideal)
        let asymSym = FaceScorer.scoreSymmetry(asym)
        XCTAssertLessThan(asymSym, idealSym)
    }

    func testClosedEyesDropTheEyesScore() {
        let ideal = buildIdealMetrics()
        var closed = FaceMetrics(boundingBox: ideal.boundingBox, imageSize: ideal.imageSize)
        closed.leftEye = ideal.leftEye
        closed.rightEye = ideal.rightEye
        closed.leftEyeContour = ideal.leftEyeContour
        closed.rightEyeContour = ideal.rightEyeContour
        closed.leftEyeOpenProbability = 0.05
        closed.rightEyeOpenProbability = 0.05

        let eyesIdeal = FaceScorer.scoreEyes(ideal)
        let eyesClosed = FaceScorer.scoreEyes(closed)
        XCTAssertLessThan(eyesClosed, eyesIdeal)
    }

    func testReturnsOneCategoryScorePerScoreCategory() {
        let m = buildIdealMetrics()
        let scores = FaceScorer.scoreAll(m)
        let cats = Set(scores.map(\.category))
        XCTAssertEqual(cats, Set(ScoreCategory.allCases))
    }
}
