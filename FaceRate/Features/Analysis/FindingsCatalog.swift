import Foundation

/// Turns category scores into the four Key Findings shown on the Score Report:
/// the two strongest as strengths, the two weakest as opportunities.
///
/// Shared by the live analysis pipeline (`VisionAnalysisService`) and the
/// history-reconstruction path (`ScanResult.reconstruct`) so the copy lives in
/// one place, and guards against fewer than four categories instead of
/// force-indexing.
enum FindingsCatalog {
    static func build(from categories: [CategoryScore]) -> [KeyFinding] {
        let sorted = categories.sorted { $0.value > $1.value }
        guard sorted.count >= 4 else {
            // Degenerate input — surface whatever we have as strengths rather
            // than crashing on a fixed index.
            return sorted.map { finding(for: $0.category, isStrength: true) }
        }
        let top = Array(sorted.prefix(2))
        let bottom = Array(sorted.suffix(2).reversed())
        return [
            finding(for: top[0].category, isStrength: true),
            finding(for: bottom[0].category, isStrength: false),
            finding(for: top[1].category, isStrength: true),
            finding(for: bottom[1].category, isStrength: false),
        ]
    }

    private static func finding(for category: ScoreCategory, isStrength: Bool) -> KeyFinding {
        let entry = (isStrength ? strengthCopy : improvementCopy)[category]!
        return KeyFinding(
            category: category,
            title: entry.0,
            body: entry.1
        )
    }

    private static let strengthCopy: [ScoreCategory: (String, String)] = [
        .symmetry: ("Balanced Features", "Strong left/right symmetry across midface landmarks."),
        .skin: ("Clear Complexion", "Skin texture reads even, with healthy tone variance."),
        .jawline: ("Strong Definition", "Excellent lateral projection along the mandible."),
        .eyes: ("Striking Eyes", "Exceptional canthal tilt and eye-to-face ratio."),
        .lips: ("Defined Lips", "Vermillion border and philtrum read sharply."),
        .nose: ("Refined Nose", "Bridge proportions sit close to ideal ratios."),
        .tone: ("Even Tone", "Skin reflectance is consistent across the cheeks."),
        .harmony: ("Golden Proportions", "Thirds and fifths align with classical ratios."),
    ]

    private static let improvementCopy: [ScoreCategory: (String, String)] = [
        .symmetry: ("Posture Focus", "Slight asymmetry — daily neck stretches can help."),
        .skin: ("Hydration Focus", "Minor texture variation detected in the cheeks."),
        .jawline: ("Jawline Routine", "Targeted exercises can sharpen lower-face definition."),
        .eyes: ("Brighten Eyes", "Sleep + cold compress will reduce undereye shadow."),
        .lips: ("Lip Care", "Hydration and SPF will preserve lip color and shape."),
        .nose: ("Contour Tip", "Subtle shading along the bridge will refine balance."),
        .tone: ("Even Out Tone", "Daily SPF + vitamin C smooths reflectance gradients."),
        .harmony: ("Frame Choices", "Glasses or hairstyles can reinforce facial thirds."),
    ]
}
