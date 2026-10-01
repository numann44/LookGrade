import SwiftUI
import UIKit

/// Design tokens for FaceRate's single calm dark appearance. The background is
/// a near-black green, surfaces lift gently without glowing, and the existing
/// mint / coral / sky palette supplies restrained playful accents.
enum AppColors {
    /// Dynamic color from a dark and a light hex.
    private static func dyn(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    // Backgrounds — soft contrast keeps long sessions comfortable.
    static let bgPrimary = dyn(0x101817, 0x101817)
    static let bgSurface = dyn(0x182321, 0x182321)
    static let bgSurfaceElevated = dyn(0x202D2A, 0x202D2A)
    static let bgSurfaceHigh = dyn(0x293734, 0x293734)

    // Text
    static let textPrimary = dyn(0xF6F0E3, 0xF6F0E3)
    static let textSecondary = dyn(0xA9B7B3, 0xA9B7B3)
    static let textTertiary = dyn(0x748480, 0x748480)

    // Borders / glass edges
    static let borderSubtle = dyn(0x30413D, 0x30413D)
    static let borderMuted = dyn(0x22302D, 0x22302D)

    // Accent — mint into sky, avoiding the generic purple-AI look.
    static let accentPrimary = dyn(0x72C89F, 0x72C89F)
    static let accentPrimaryHover = dyn(0x62B78F, 0x62B78F)
    static let accentOnPrimary = Color.white
    static let accentGlow = dyn(0x72C89F, 0x72C89F).opacity(0.24)
    static let accentGradStart = dyn(0x72C89F, 0x72C89F)
    static let accentGradEnd = dyn(0x6EB7ED, 0x6EB7ED)

    /// The brand gradient — primary CTAs, the score ring, hero glows.
    static let accentGradient = LinearGradient(
        colors: [accentGradStart, accentGradEnd],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    // State — refined jewel tones (deeper in light so they stay legible)
    static let stateSuccess = dyn(0x35D08A, 0x17915C)
    static let stateWarning = dyn(0xF5B347, 0xB77A12)
    static let stateDanger = dyn(0xFF5B5B, 0xD82A2A)
    static let stateStreak = dyn(0xFF8A42, 0xE06A1E)

    // Glass material — highlight + shadow adapt to the surface
    static let glassHighlight = Color(uiColor: UIColor { t in
        UIColor(white: t.userInterfaceStyle == .dark ? 1 : 1, alpha: t.userInterfaceStyle == .dark ? 0.05 : 0.55)
    })
    static let glassShadow = Color(uiColor: UIColor { t in
        UIColor(white: 0, alpha: t.userInterfaceStyle == .dark ? 0.35 : 0.10)
    })

    // Capture — always shown over the live camera / analyzing photo, so these
    // stay bright regardless of theme.
    static let captureBracket = Color(rgb: 0xF4F4F7)
    static let captureOval = Color(rgb: 0x72C89F)

    // Analyzing mesh overlay
    static let meshGrid = Color(uiColor: UIColor { t in
        UIColor(white: t.userInterfaceStyle == .dark ? 1 : 0, alpha: 0.07)
    })
    static let meshScanline = Color(rgb: 0x72C89F)

    /// Per-category jewel colors (order matches `ScoreCategory`).
    static func score(for category: ScoreCategory) -> Color {
        switch category {
        case .symmetry: return dyn(0xA78BFA, 0x7C5CE0) // violet
        case .skin:     return dyn(0x35D08A, 0x17915C) // mint
        case .jawline:  return dyn(0xFF9E6B, 0xD2652A) // coral
        case .eyes:     return dyn(0x57C6FF, 0x1E86C8) // sky
        case .lips:     return dyn(0xFF7AA8, 0xD24A7C) // pink
        case .nose:     return dyn(0xFFD24E, 0xB7860B) // gold
        case .tone:     return dyn(0x57E0CE, 0x148F82) // teal
        case .harmony:  return dyn(0xC9A8FF, 0x8A5CE0) // light violet
        }
    }

    /// A soft two-stop gradient tinted to a category — for premium score bars.
    static func gradient(for category: ScoreCategory) -> LinearGradient {
        let base = score(for: category)
        return LinearGradient(
            colors: [base.opacity(0.75), base],
            startPoint: .leading, endPoint: .trailing
        )
    }
}

/// Playful accents shared by the product's main screens.
enum JoyColors {
    private static func dyn(_ dark: UInt32, _ light: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    static let canvas = dyn(0x101817, 0x101817)
    static let surface = dyn(0x182321, 0x182321)
    static let ink = dyn(0xF6F0E3, 0xF6F0E3)
    static let muted = dyn(0xA9B7B3, 0xA9B7B3)
    static let coral = dyn(0xFF786D, 0xFF786D)
    static let coralSoft = dyn(0x3A2523, 0x3A2523)
    static let lemon = dyn(0xE8C44F, 0xE8C44F)
    static let sky = dyn(0x6EB7ED, 0x6EB7ED)
    static let mint = dyn(0x72C89F, 0x72C89F)
    static let orange = dyn(0xF0A35B, 0xF0A35B)
    static let white = Color.white
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init(rgb: UInt32) { self.init(hex: rgb) }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }
}
