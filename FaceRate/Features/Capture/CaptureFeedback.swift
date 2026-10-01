import CoreMedia
import CoreVideo
import Vision

/// Live coaching signal computed from camera frames during capture — drives
/// the oval guide state, the lighting indicator, the hint text, and
/// auto-capture. Face position/size are orientation-invariant enough (center
/// stays center under the preview's rotation + mirroring; area is
/// rotation-agnostic) that we don't need exact frame orientation here.
struct CaptureFeedback: Equatable {
    enum Quality { case searching, aligned, tooDark, tooBright }
    let quality: Quality
    let hasFace: Bool

    var guideState: CaptureGuideState {
        switch quality {
        case .searching: return .searching
        case .aligned: return .aligned
        case .tooDark: return .tooDark
        case .tooBright: return .tooBright
        }
    }

    var isWellLit: Bool { quality != .tooDark && quality != .tooBright }

    static func make(luminance: Double, faceRect: CGRect?) -> CaptureFeedback {
        if luminance < 0.14 { return .init(quality: .tooDark, hasFace: faceRect != nil) }
        if luminance > 0.92 { return .init(quality: .tooBright, hasFace: faceRect != nil) }
        guard let r = faceRect else { return .init(quality: .searching, hasFace: false) }
        let area = r.width * r.height
        let centered = abs(r.midX - 0.5) < 0.18 && abs(r.midY - 0.5) < 0.22
        let goodSize = area > 0.07 && area < 0.75
        return .init(quality: (centered && goodSize) ? .aligned : .searching, hasFace: true)
    }
}

/// Cheap per-frame analysis of a BGRA pixel buffer.
enum FrameAnalyzer {
    private static let faceRequest = VNDetectFaceRectanglesRequest()

    /// Mean luminance (0…1) from a coarse grid of pixels — fast, no full scan.
    static func meanLuminance(_ pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return 0.5 }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        let stepX = max(1, width / 24)
        let stepY = max(1, height / 24)
        var total = 0.0
        var count = 0
        var y = 0
        while y < height {
            var x = 0
            let row = y * bytesPerRow
            while x < width {
                let i = row + x * 4 // BGRA
                let b = Double(ptr[i]); let g = Double(ptr[i + 1]); let r = Double(ptr[i + 2])
                total += (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
                count += 1
                x += stepX
            }
            y += stepY
        }
        return count > 0 ? total / Double(count) : 0.5
    }

    /// Largest detected face bounding box (Vision normalized coords), or nil.
    static func largestFaceRect(_ pixelBuffer: CVPixelBuffer) -> CGRect? {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([faceRequest])
        guard let results = faceRequest.results, !results.isEmpty else { return nil }
        return results.max { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }?.boundingBox
    }
}
