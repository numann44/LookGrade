import CoreGraphics
import Foundation

/// Derived descriptors surfaced on the report alongside the numeric scores —
/// face shape from the oval contour and undertone from cheek color. Both use
/// data the pipeline already computes; heuristic, like the scores.
enum FaceProfile {
    /// Classifies face shape from the oval contour's width at three heights
    /// (forehead / cheeks / jaw) versus overall length. Returns nil when the
    /// contour is too sparse to judge.
    static func faceShape(from m: FaceMetrics) -> String? {
        guard m.faceOval.count >= 8 else { return nil }
        let ys = m.faceOval.map { Double($0.y) }
        guard let top = ys.min(), let bottom = ys.max() else { return nil }
        let height = bottom - top
        guard height > 1 else { return nil }

        func width(atFraction f: Double) -> Double {
            let yTarget = top + f * height
            let band = 0.14 * height
            let xs = m.faceOval.filter { abs(Double($0.y) - yTarget) < band }.map { Double($0.x) }
            guard let minX = xs.min(), let maxX = xs.max(), xs.count >= 2 else { return 0 }
            return maxX - minX
        }

        let forehead = width(atFraction: 0.22)
        let cheek = max(width(atFraction: 0.50), m.faceWidth * 0.5)
        let jaw = width(atFraction: 0.82)
        guard cheek > 1 else { return nil }

        let lengthRatio = height / cheek
        let jawToCheek = jaw / cheek
        let foreheadToJaw = forehead / max(jaw, 1)

        if lengthRatio > 1.55 { return "Oblong" }
        if foreheadToJaw > 1.25 { return "Heart" }
        if jawToCheek > 0.92 && lengthRatio < 1.28 { return "Square" }
        if lengthRatio < 1.15 { return "Round" }
        return "Oval"
    }

    /// Warm / cool / neutral undertone from mean cheek RGB (red-vs-blue lean).
    static func undertone(from sample: SkinSample?) -> String? {
        guard let sample else { return nil }
        let r = (sample.leftMean.r + sample.rightMean.r) / 2
        let b = (sample.leftMean.b + sample.rightMean.b) / 2
        let delta = (r - b) / 255.0
        if delta > 0.06 { return "Warm" }
        if delta < -0.06 { return "Cool" }
        return "Neutral"
    }
}
