import Foundation

/// Thrown when the detector finds no face in the captured image.
struct NoFaceDetectedError: LocalizedError {
    var errorDescription: String? {
        NSLocalizedString("No face detected. Re-take with better lighting and your face centered.", comment: "analysis error")
    }
}

/// Thrown when a face is found but the capture is too poor to score honestly
/// (too far, too dark, too much glare, or turned away). Carries actionable
/// retake guidance shown on the analyzing screen's error card.
struct ScanQualityError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

protocol AnalysisService {
    func analyze(_ input: ScanInput) async throws -> ScanResult
}
