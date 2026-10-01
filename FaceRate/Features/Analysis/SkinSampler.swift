import CoreGraphics
import Foundation

/// Samples luminance/RGB from the cheek regions inferred from `FaceMetrics`.
/// Vision has no cheek landmark at all (unlike ML Kit), so the face-box-
/// relative fallback below is the PRIMARY method, not a fallback-of-last-
/// resort like it was in skin_sampler.dart.
struct SkinSampler {
    func sample(metrics: FaceMetrics, image: CGImage) async -> SkinSample? {
        await Task.detached(priority: .userInitiated) {
            Self.sampleSync(metrics: metrics, image: image)
        }.value
    }

    private static func sampleSync(metrics: FaceMetrics, image: CGImage) -> SkinSample? {
        guard let buffer = pixelBuffer(from: image) else { return nil }

        let cheekSize = min(max(metrics.faceWidth * 0.18, 8), 160)
        let faceLeft = Double(metrics.boundingBox.minX)
        let faceTop = Double(metrics.boundingBox.minY)
        let lcx = metrics.leftCheek.map { Double($0.x) } ?? faceLeft + metrics.faceWidth * 0.30
        let lcy = metrics.leftCheek.map { Double($0.y) } ?? faceTop + metrics.faceHeight * 0.65
        let rcx = metrics.rightCheek.map { Double($0.x) } ?? faceLeft + metrics.faceWidth * 0.70
        let rcy = metrics.rightCheek.map { Double($0.y) } ?? faceTop + metrics.faceHeight * 0.65

        let leftRect = CGRect(x: lcx - cheekSize / 2, y: lcy - cheekSize / 2, width: cheekSize, height: cheekSize)
        let rightRect = CGRect(x: rcx - cheekSize / 2, y: rcy - cheekSize / 2, width: cheekSize, height: cheekSize)

        guard let left = sampleRect(buffer, leftRect), let right = sampleRect(buffer, rightRect) else { return nil }

        let lumVals = left.lumValues + right.lumValues
        let mean = lumVals.reduce(0, +) / Double(lumVals.count)
        var variance = 0.0
        for v in lumVals { let d = v - mean; variance += d * d }
        variance /= Double(lumVals.count)
        let std = sqrt(variance) / 255.0

        let leftMean = RgbMean(r: left.rMean, g: left.gMean, b: left.bMean)
        let rightMean = RgbMean(r: right.rMean, g: right.gMean, b: right.bMean)
        let sat = (saturation(leftMean) + saturation(rightMean)) / 2

        return SkinSample(
            meanLuminance: min(max(mean / 255.0, 0), 1),
            luminanceStdDev: min(max(std, 0), 1),
            leftMean: leftMean,
            rightMean: rightMean,
            saturation: sat
        )
    }

    private struct PixelBuffer {
        let data: [UInt8]
        let width: Int
        let height: Int
        let bytesPerRow: Int
    }

    private static func pixelBuffer(from image: CGImage) -> PixelBuffer? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        // Flip so buffer row 0 == image top, matching the top-left pixel
        // coordinates FaceMetrics/VisionAnalysisService use everywhere else.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return PixelBuffer(data: pixelData, width: width, height: height, bytesPerRow: bytesPerRow)
    }

    private struct RegionStats {
        let lumValues: [Double]
        let rMean: Double, gMean: Double, bMean: Double
    }

    /// Stride to keep the sample size bounded (~400 pixels), matching
    /// skin_sampler.dart's `_sampleRect`.
    private static func sampleRect(_ buffer: PixelBuffer, _ rect: CGRect) -> RegionStats? {
        let left = max(0, min(buffer.width - 1, Int(rect.minX)))
        let right = max(0, min(buffer.width - 1, Int(rect.maxX)))
        let top = max(0, min(buffer.height - 1, Int(rect.minY)))
        let bottom = max(0, min(buffer.height - 1, Int(rect.maxY)))
        guard right > left, bottom > top else { return nil }

        let pixelCount = (right - left) * (bottom - top)
        let targetSamples = 400
        let step = max(1, Int((Double(pixelCount) / Double(targetSamples)).squareRoot().rounded()))

        var lumValues: [Double] = []
        var sumR = 0.0, sumG = 0.0, sumB = 0.0
        var n = 0
        var y = top
        while y < bottom {
            var x = left
            while x < right {
                let offset = y * buffer.bytesPerRow + x * 4
                let r = Double(buffer.data[offset])
                let g = Double(buffer.data[offset + 1])
                let b = Double(buffer.data[offset + 2])
                // ITU-R BT.601 luminance.
                lumValues.append(0.299 * r + 0.587 * g + 0.114 * b)
                sumR += r; sumG += g; sumB += b
                n += 1
                x += step
            }
            y += step
        }
        guard n > 0 else { return nil }
        return RegionStats(lumValues: lumValues, rMean: sumR / Double(n), gMean: sumG / Double(n), bMean: sumB / Double(n))
    }

    private static func saturation(_ rgb: RgbMean) -> Double {
        let r = rgb.r / 255.0, g = rgb.g / 255.0, b = rgb.b / 255.0
        let maxC = max(r, max(g, b))
        let minC = min(r, min(g, b))
        guard maxC > 0 else { return 0 }
        return min(max((maxC - minC) / maxC, 0), 1)
    }
}
