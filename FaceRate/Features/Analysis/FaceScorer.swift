import CoreGraphics
import Foundation

/// Pure-Swift per-category scorer. Maps geometric/landmark signals from
/// `FaceMetrics` into 0...10 scores. Ported formula-for-formula from
/// face_scorer.dart — see that file's header for the heuristic-not-clinical
/// disclaimer this inherits.
enum FaceScorer {
    private static func toDisplayScore(_ quality: Double) -> Double {
        let clamped = min(max(quality, 0), 1)
        let v = 5.5 + 4.0 * clamped
        return (v * 10).rounded() / 10
    }

    // ---------- Symmetry ----------
    static func scoreSymmetry(_ m: FaceMetrics) -> Double {
        var quality = 0.5

        // Head pose penalty: turning your head off-axis reduces measurable
        // symmetry. Penalize yaw/roll, plus pitch (chin up/down) at half
        // weight since it foreshortens vertical proportions too.
        let pose = (abs(m.headEulerY) + abs(m.headEulerZ) + abs(m.headEulerX) * 0.5) / 24.0
        let posePenalty = min(max(pose, 0), 0.5)

        if let leftEye = m.leftEye, let rightEye = m.rightEye {
            let cx = m.faceCenter.x
            let dxL = Double(abs(leftEye.x - cx))
            let dxR = Double(abs(rightEye.x - cx))
            let diff = abs(dxL - dxR)
            let norm = diff / (m.faceWidth + 1e-6)
            quality = min(max(1 - norm * 8, 0), 1)
        }

        if let leftMouth = m.leftMouth, let rightMouth = m.rightMouth {
            let cx = m.faceCenter.x
            let dxL = Double(abs(leftMouth.x - cx))
            let dxR = Double(abs(rightMouth.x - cx))
            let diff = abs(dxL - dxR)
            let norm = diff / (m.faceWidth + 1e-6)
            let mq = min(max(1 - norm * 8, 0), 1)
            quality = (quality + mq) / 2
        }

        // Face oval contour symmetry: pair i with (n-1-i).
        if m.faceOval.count >= 8 {
            let cx = m.faceCenter.x
            var err = 0.0
            var n = 0
            let half = m.faceOval.count / 2
            for i in 0..<half {
                let p = m.faceOval[i]
                let q = m.faceOval[m.faceOval.count - 1 - i]
                let reflectedX = 2 * cx - p.x
                let dx = Double(abs(reflectedX - q.x)) / (m.faceWidth + 1e-6)
                let dy = Double(abs(p.y - q.y)) / (m.faceHeight + 1e-6)
                err += dx + dy
                n += 1
            }
            if n > 0 {
                let cq = min(max(1 - err / Double(n) * 6, 0), 1)
                quality = (quality + cq) / 2
            }
        }

        return toDisplayScore(min(max(quality - posePenalty, 0), 1))
    }

    // ---------- Jawline ----------
    static func scoreJawline(_ m: FaceMetrics) -> Double {
        if m.faceOval.count < 8 {
            // Fallback: bounding-box aspect ratio.
            let aspect = m.faceHeight / (m.faceWidth + 1e-6)
            let q = FaceGeo.triangular(aspect, peak: 1.40, tolerance: 0.45)
            return toDisplayScore(q)
        }

        let chin = m.faceOval.max { $0.y < $1.y }!
        let cy = m.faceCenter.y
        let jawZone = m.faceOval.filter { $0.y > cy }.sorted { $0.x < $1.x }
        if jawZone.count < 4 {
            return toDisplayScore(0.55)
        }
        let leftJaw = jawZone.first!
        let rightJaw = jawZone.last!

        // Chin angle: smaller (sharper) = better V-taper. Ideal ~120deg.
        let angleRad = FaceGeo.angleAt(leftJaw, chin, rightJaw)
        let angleDeg = angleRad * 180 / .pi
        let qAngle = FaceGeo.triangular(angleDeg, peak: 120, tolerance: 35)

        // Jaw width / face width — lower jaw width relative to face = stronger taper.
        let jawWidth = Double(abs(rightJaw.x - leftJaw.x))
        let ratio = jawWidth / (m.faceWidth + 1e-6)
        let qRatio = FaceGeo.triangular(ratio, peak: 0.78, tolerance: 0.18)

        return toDisplayScore(min(max(qAngle * 0.6 + qRatio * 0.4, 0), 1))
    }

    // ---------- Eyes ----------
    static func scoreEyes(_ m: FaceMetrics) -> Double {
        var components: [Double] = []

        let open = (m.leftEyeOpenProbability + m.rightEyeOpenProbability) / 2
        components.append(min(max(open, 0), 1))

        if !m.leftEyeContour.isEmpty, !m.rightEyeContour.isEmpty {
            let lW = Double(FaceGeo.bbox(of: m.leftEyeContour)?.width ?? 0)
            let rW = Double(FaceGeo.bbox(of: m.rightEyeContour)?.width ?? 0)
            let avg = (lW + rW) / 2
            let ratio = avg / (m.faceWidth + 1e-6)
            components.append(FaceGeo.triangular(ratio, peak: 0.20, tolerance: 0.07))

            let widthDelta = abs(lW - rW) / (avg + 1e-6)
            components.append(min(max(1 - widthDelta * 4, 0), 1))
        } else if let leftEye = m.leftEye, let rightEye = m.rightEye {
            // Inter-pupillary distance / face width — target ~0.46.
            let ipd = FaceGeo.dist(leftEye, rightEye)
            let ratio = ipd / (m.faceWidth + 1e-6)
            components.append(FaceGeo.triangular(ratio, peak: 0.46, tolerance: 0.15))
        }

        // Canthal tilt (positive = outer corner higher than inner).
        if m.leftEyeContour.count >= 4, m.rightEyeContour.count >= 4 {
            let lOuter = m.leftEyeContour.min { $0.x < $1.x }!
            let lInner = m.leftEyeContour.max { $0.x < $1.x }!
            let rInner = m.rightEyeContour.min { $0.x < $1.x }!
            let rOuter = m.rightEyeContour.max { $0.x < $1.x }!
            let tiltL = Double(lInner.y - lOuter.y) / (m.faceHeight + 1e-6)
            let tiltR = Double(rInner.y - rOuter.y) / (m.faceHeight + 1e-6)
            let avgTilt = (tiltL + tiltR) / 2
            components.append(FaceGeo.triangular(avgTilt, peak: 0.012, tolerance: 0.025))
        }

        let q = components.reduce(0, +) / Double(components.count)
        return toDisplayScore(q)
    }

    // ---------- Lips ----------
    static func scoreLips(_ m: FaceMetrics) -> Double {
        let lipPts = m.upperLipTop + m.upperLipBottom + m.lowerLipTop + m.lowerLipBottom
        if lipPts.isEmpty {
            if let leftMouth = m.leftMouth, let rightMouth = m.rightMouth, m.bottomMouth != nil {
                let width = FaceGeo.dist(leftMouth, rightMouth)
                let ratio = width / (m.faceWidth + 1e-6)
                let q = FaceGeo.triangular(ratio, peak: 0.45, tolerance: 0.12)
                return toDisplayScore(q)
            }
            return toDisplayScore(0.55)
        }
        let box = FaceGeo.bbox(of: lipPts)!
        let widthRatio = Double(box.width) / (m.faceWidth + 1e-6)
        let heightRatio = Double(box.height) / (m.faceHeight + 1e-6)
        let qWidth = FaceGeo.triangular(widthRatio, peak: 0.46, tolerance: 0.12)
        let qHeight = FaceGeo.triangular(heightRatio, peak: 0.06, tolerance: 0.04)

        // Top/bottom thickness symmetry (both lips similarly thick = balanced).
        let upperBox = Double(FaceGeo.bbox(of: m.upperLipTop + m.upperLipBottom)?.height ?? 0)
        let lowerBox = Double(FaceGeo.bbox(of: m.lowerLipTop + m.lowerLipBottom)?.height ?? 0)
        let ratio = lowerBox / (upperBox + 1e-6)
        let qBalance = FaceGeo.triangular(ratio, peak: 1.2, tolerance: 0.6)

        let q = min(max(qWidth * 0.45 + qHeight * 0.30 + qBalance * 0.25, 0), 1)
        return toDisplayScore(q)
    }

    // ---------- Nose ----------
    static func scoreNose(_ m: FaceMetrics) -> Double {
        var components: [Double] = []

        let noseWidthSrc = m.noseBottom.isEmpty ? m.noseBridge : m.noseBottom
        if !noseWidthSrc.isEmpty {
            let box = FaceGeo.bbox(of: noseWidthSrc)!
            let ratio = Double(box.width) / (m.faceWidth + 1e-6)
            components.append(FaceGeo.triangular(ratio, peak: 0.27, tolerance: 0.08))
        }

        if !m.noseBridge.isEmpty, !m.noseBottom.isEmpty {
            let top = m.noseBridge.min { $0.y < $1.y }!
            let bot = m.noseBottom.max { $0.y < $1.y }!
            let length = Double(abs(bot.y - top.y))
            let ratio = length / (m.faceHeight + 1e-6)
            components.append(FaceGeo.triangular(ratio, peak: 0.33, tolerance: 0.10))
        }

        // Bridge straightness — variance of x along bridge.
        if m.noseBridge.count >= 3 {
            let cx = FaceGeo.centroid(m.noseBridge).x
            var v = 0.0
            for p in m.noseBridge {
                let d = Double(abs(p.x - cx)) / (m.faceWidth + 1e-6)
                v += d * d
            }
            v /= Double(m.noseBridge.count)
            components.append(min(max(1 - v * 800, 0), 1))
        }

        if components.isEmpty {
            if let noseBase = m.noseBase {
                let dy = Double(noseBase.y - m.faceCenter.y) / (m.faceHeight + 1e-6)
                components.append(FaceGeo.triangular(dy, peak: 0.05, tolerance: 0.10))
            } else {
                return toDisplayScore(0.55)
            }
        }
        let q = components.reduce(0, +) / Double(components.count)
        return toDisplayScore(q)
    }

    // ---------- Harmony (facial thirds + ratios) ----------
    static func scoreHarmony(_ m: FaceMetrics) -> Double {
        var components: [Double] = []

        if let leftEye = m.leftEye, let rightEye = m.rightEye, let bottomMouth = m.bottomMouth {
            let eyeLine = Double(leftEye.y + rightEye.y) / 2
            let mouth = Double(bottomMouth.y)
            let chin = Double(m.boundingBox.maxY)
            let midToChin = abs(chin - mouth)
            let eyeToMouth = abs(mouth - eyeLine)
            let ratio = midToChin / (eyeToMouth + 1e-6)
            // Ideal ~0.5 (mouth-to-chin is half eye-to-mouth).
            components.append(FaceGeo.triangular(ratio, peak: 0.50, tolerance: 0.30))
        }

        if let leftEye = m.leftEye, let rightEye = m.rightEye, !m.leftEyeContour.isEmpty {
            let ipd = FaceGeo.dist(leftEye, rightEye)
            let eyeWidth = Double(FaceGeo.bbox(of: m.leftEyeContour)?.width ?? 0)
            let ratio = ipd / (eyeWidth + 1e-6)
            components.append(FaceGeo.triangular(ratio, peak: 2.0, tolerance: 0.7))
        }

        if let leftEye = m.leftEye, let rightEye = m.rightEye,
           let leftMouth = m.leftMouth, let rightMouth = m.rightMouth {
            let ipd = FaceGeo.dist(leftEye, rightEye)
            let mw = FaceGeo.dist(leftMouth, rightMouth)
            let ratio = mw / (ipd + 1e-6)
            components.append(FaceGeo.triangular(ratio, peak: 1.30, tolerance: 0.40))
        }

        if components.isEmpty { return toDisplayScore(0.6) }
        let q = components.reduce(0, +) / Double(components.count)
        return toDisplayScore(q)
    }

    // ---------- Skin / Tone (uses SkinSample if present) ----------
    static func scoreSkin(_ m: FaceMetrics, sample: SkinSample?) -> Double {
        guard let sample else {
            // No pixel sample (sampler failed) — skin quality is genuinely
            // unmeasurable here, so return a neutral mid read rather than
            // inferring it from unrelated signals like smile/eye-openness.
            return toDisplayScore(0.5)
        }
        // Lower luminance variance ~= smoother skin reads. Cheek samples only.
        let qSmooth = FaceGeo.triangular(sample.luminanceStdDev, peak: 0.06, tolerance: 0.10)
        // Mid-range mean luminance reads as well-lit skin.
        let qLight = FaceGeo.triangular(sample.meanLuminance, peak: 0.55, tolerance: 0.30)
        let q = min(max(qSmooth * 0.65 + qLight * 0.35, 0), 1)
        return toDisplayScore(q)
    }

    static func scoreTone(_ m: FaceMetrics, sample: SkinSample?) -> Double {
        guard let sample else {
            return toDisplayScore(0.55 + min(max(1 - abs(m.headEulerY) / 30, 0), 0.30))
        }
        // Even tone — left vs right cheek similarity.
        let dr = abs(sample.leftMean.r - sample.rightMean.r)
        let dg = abs(sample.leftMean.g - sample.rightMean.g)
        let db = abs(sample.leftMean.b - sample.rightMean.b)
        let delta = (dr + dg + db) / 3 / 255.0
        let qEven = min(max(1 - delta * 8, 0), 1)
        // Saturation in a healthy band.
        let qSat = FaceGeo.triangular(sample.saturation, peak: 0.18, tolerance: 0.18)
        let q = min(max(qEven * 0.65 + qSat * 0.35, 0), 1)
        return toDisplayScore(q)
    }

    // ---------- Aggregate ----------
    static func scoreAll(_ m: FaceMetrics, sample: SkinSample? = nil) -> [CategoryScore] {
        [
            CategoryScore(category: .symmetry, value: scoreSymmetry(m)),
            CategoryScore(category: .skin, value: scoreSkin(m, sample: sample)),
            CategoryScore(category: .jawline, value: scoreJawline(m)),
            CategoryScore(category: .eyes, value: scoreEyes(m)),
            CategoryScore(category: .lips, value: scoreLips(m)),
            CategoryScore(category: .nose, value: scoreNose(m)),
            CategoryScore(category: .tone, value: scoreTone(m, sample: sample)),
            CategoryScore(category: .harmony, value: scoreHarmony(m)),
        ]
    }

    /// Overall = weighted mean (symmetry/harmony/skin weighted higher).
    static func overall(_ scores: [CategoryScore]) -> Double {
        let weights: [ScoreCategory: Double] = [
            .symmetry: 1.4, .skin: 1.2, .jawline: 1.1, .eyes: 1.2,
            .lips: 1.0, .nose: 1.0, .tone: 1.0, .harmony: 1.3,
        ]
        var sum = 0.0, w = 0.0
        for cs in scores {
            let wi = weights[cs.category] ?? 1.0
            sum += cs.value * wi
            w += wi
        }
        let v = sum / w
        return (v * 10).rounded() / 10
    }
}
