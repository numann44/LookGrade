import Foundation

/// Seed data shown before the user has run their first real scan.
/// Replaced at runtime by a real `ScanResult` from the analysis pipeline.
enum MockScanData {
    static let overallScore = 8.2
    static let potentialDelta = 0.4

    static let categoryScores: [CategoryScore] = [
        CategoryScore(category: .symmetry, value: 8.5),
        CategoryScore(category: .skin, value: 7.8),
        CategoryScore(category: .jawline, value: 8.2),
        CategoryScore(category: .eyes, value: 9.0),
        CategoryScore(category: .lips, value: 8.1),
        CategoryScore(category: .nose, value: 7.5),
        CategoryScore(category: .tone, value: 8.4),
        CategoryScore(category: .harmony, value: 8.3),
    ]

    static let findings: [KeyFinding] = [
        KeyFinding(category: .eyes, title: L10n.text("Striking Eyes"), body: L10n.text("Exceptional canthal tilt and symmetry observed.")),
        KeyFinding(category: .skin, title: L10n.text("Hydration Focus"), body: L10n.text("Minor texture variations detected in T-zone.")),
        KeyFinding(category: .jawline, title: L10n.text("Strong Definition"), body: L10n.text("Excellent lateral projection on the mandible.")),
        KeyFinding(category: .harmony, title: L10n.text("Proportions"), body: L10n.text("Golden ratio alignment is highly optimal.")),
    ]

    static func seedResult() -> ScanResult {
        ScanResult(
            input: ScanInput(imagePath: "", capturedAt: Date(), source: .mock),
            overallScore: overallScore,
            potentialDelta: potentialDelta,
            categories: categoryScores,
            findings: findings
        )
    }
}
