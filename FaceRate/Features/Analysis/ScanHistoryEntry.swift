import Foundation

/// A persisted summary of a single scan. Deliberately does NOT store the
/// captured image — too large, quickly stale. Photo is shown only for the
/// live, in-memory result on the Score Report.
struct ScanHistoryEntry: Codable, Identifiable, Equatable {
    let id: String
    let capturedAt: Date
    let overallScore: Double
    let potentialDelta: Double
    /// `ScoreCategory.rawValue` -> value (the Codable-friendly storage shape).
    let categories: [String: Double]

    init(id: String, capturedAt: Date, overallScore: Double, potentialDelta: Double, categories: [ScoreCategory: Double]) {
        self.id = id
        self.capturedAt = capturedAt
        self.overallScore = overallScore
        self.potentialDelta = potentialDelta
        self.categories = Dictionary(uniqueKeysWithValues: categories.map { ($0.key.rawValue, $0.value) })
    }

    var categoryScores: [CategoryScore] {
        categories.compactMap { key, value in
            guard let cat = ScoreCategory(rawValue: key) else { return nil }
            return CategoryScore(category: cat, value: value)
        }
    }

    /// Deterministic id derived from capture time, so the persisted photo
    /// thumbnail (`ScanPhotoLibrary`) can be keyed to the same entry.
    static func id(forCapturedAt ts: Date) -> String {
        String(Int(ts.timeIntervalSince1970 * 1000))
    }

    static func from(result: ScanResult) -> ScanHistoryEntry {
        let ts = result.input.capturedAt
        var cats: [ScoreCategory: Double] = [:]
        for cs in result.categories { cats[cs.category] = cs.value }
        return ScanHistoryEntry(id: id(forCapturedAt: ts), capturedAt: ts, overallScore: result.overallScore, potentialDelta: result.potentialDelta, categories: cats)
    }
}
