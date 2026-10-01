import Foundation

/// The 8 scored facial categories. Order is meaningful — it drives display
/// order on the Score Report (DESIGN.md §4.6) and Progress category chips.
enum ScoreCategory: String, CaseIterable, Codable {
    case symmetry
    case skin
    case jawline
    case eyes
    case lips
    case nose
    case tone
    case harmony

    var label: String {
        switch self {
        case .symmetry: return NSLocalizedString("Symmetry", comment: "category")
        case .skin: return NSLocalizedString("Skin Quality", comment: "category")
        case .jawline: return NSLocalizedString("Jawline", comment: "category")
        case .eyes: return NSLocalizedString("Eyes", comment: "category")
        case .lips: return NSLocalizedString("Lips", comment: "category")
        case .nose: return NSLocalizedString("Nose", comment: "category")
        case .tone: return NSLocalizedString("Tone", comment: "category")
        case .harmony: return NSLocalizedString("Harmony", comment: "category")
        }
    }
}

struct CategoryScore: Codable, Equatable {
    let category: ScoreCategory
    let value: Double
}
