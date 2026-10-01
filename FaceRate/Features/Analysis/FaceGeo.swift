import CoreGraphics
import Foundation

/// Small geometry helpers used by `FaceScorer`. Pure math, no ML/Vision
/// dependency — ported verbatim from face_metrics.dart's `FaceGeo`.
enum FaceGeo {
    static func dist(_ a: CGPoint, _ b: CGPoint) -> Double {
        Double(hypot(a.x - b.x, a.y - b.y))
    }

    static func bbox(of points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for p in points {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    static func centroid(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        var sx: CGFloat = 0, sy: CGFloat = 0
        for p in points { sx += p.x; sy += p.y }
        return CGPoint(x: sx / CGFloat(points.count), y: sy / CGFloat(points.count))
    }

    /// Triangular score curve: `peak` returns 1.0; deviation by `tolerance`
    /// returns 0.0; clamped.
    static func triangular(_ v: Double, peak: Double, tolerance: Double) -> Double {
        let delta = abs(v - peak)
        return min(max(1 - delta / tolerance, 0), 1)
    }

    /// Angle (radians) at vertex `b` formed by points a-b-c.
    static func angleAt(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Double {
        let v1x = a.x - b.x, v1y = a.y - b.y
        let v2x = c.x - b.x, v2y = c.y - b.y
        let dot = Double(v1x * v2x + v1y * v2y)
        let m1 = Double(hypot(v1x, v1y))
        let m2 = Double(hypot(v2x, v2y))
        if m1 == 0 || m2 == 0 { return 0 }
        let cosVal = min(max(dot / (m1 * m2), -1), 1)
        return acos(cosVal)
    }
}
