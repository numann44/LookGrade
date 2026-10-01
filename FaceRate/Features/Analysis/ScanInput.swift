import Foundation

enum ScanSource: String, Codable {
    case camera, gallery, mock
}

/// Input to the analysis pipeline. `imagePath` is a local file URL string;
/// empty for the mock seed result.
struct ScanInput: Codable, Equatable {
    let imagePath: String
    let capturedAt: Date
    var source: ScanSource = .camera
}
