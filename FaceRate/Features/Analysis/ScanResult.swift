import Foundation

/// A short human-readable insight surfaced on the Score Report. `category`
/// controls which accent color the card uses.
struct KeyFinding: Identifiable, Equatable, Codable {
    var id: String { category.rawValue + title }
    let category: ScoreCategory
    let title: String
    let body: String
}

/// Output of the analysis pipeline. Carries `input` so downstream screens
/// can render the captured image alongside the scores. `Codable` so the most
/// recent result can be persisted (see `LastResultStore`).
struct ScanResult: Codable, Equatable {
    let input: ScanInput
    let overallScore: Double
    let potentialDelta: Double
    let categories: [CategoryScore]
    let findings: [KeyFinding]
    /// Derived descriptors (heuristic). Optional + defaulted so older persisted
    /// results and the reconstruction path decode/build without them.
    var faceShape: String? = nil
    var undertone: String? = nil

    func score(for category: ScoreCategory) -> Double {
        categories.first { $0.category == category }?.value ?? 0
    }
}

extension ScanResult {
    /// Rebuilds a displayable result from a persisted history summary, which
    /// stores per-category scores but not findings or the photo. Findings are
    /// regenerated from the shared `FindingsCatalog`; `imagePath` is empty.
    /// The report can retrieve the separately stored thumbnail by scan ID.
    static func reconstruct(from entry: ScanHistoryEntry) -> ScanResult {
        let categories = ScoreCategory.allCases.compactMap { cat -> CategoryScore? in
            guard let value = entry.categories[cat.rawValue] else { return nil }
            return CategoryScore(category: cat, value: value)
        }
        return ScanResult(
            input: ScanInput(imagePath: "", capturedAt: entry.capturedAt, source: .mock),
            overallScore: entry.overallScore,
            potentialDelta: entry.potentialDelta,
            categories: categories,
            findings: FindingsCatalog.build(from: categories)
        )
    }
}
