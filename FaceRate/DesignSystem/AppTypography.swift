import SwiftUI
import UIKit

/// Named text styles — "Aura" premium-dark system.
///
/// Clean and modern, no themed gimmicks:
/// • **Rounded** (SF Pro Rounded) for big numbers only — the friendly,
///   premium numerals of a fitness/health app.
/// • **Sans** (SF Pro) for everything else, with a tight, confident scale.
///
/// Fonts come from the system with a design variant, scaled through
/// `UIFontMetrics` so Dynamic Type still works up to 200%.
enum AppTextStyle {
    case displayLarge   // rounded — hero score number
    case displayMedium  // sans    — onboarding / big titles
    case h1             // sans    — screen titles
    case h2             // sans    — section headers
    case h3             // sans    — card titles
    case body           // sans    — paragraphs
    case bodyStrong     // sans    — emphasis
    case caption        // sans    — meta, dates
    case overline       // sans    — UPPERCASE labels
    case mono           // rounded — tabular readout numbers
    case tipNumber      // rounded — numbered badge

    fileprivate var size: CGFloat {
        switch self {
        case .displayLarge: return 46
        case .displayMedium: return 28
        case .h1: return 26
        case .h2: return 20
        case .h3: return 16
        case .body, .bodyStrong: return 15
        case .caption: return 13
        case .overline: return 11
        case .mono: return 15
        case .tipNumber: return 12
        }
    }

    fileprivate var lineHeight: CGFloat {
        switch self {
        case .displayLarge: return 50
        case .displayMedium: return 34
        case .h1: return 32
        case .h2: return 26
        case .h3: return 22
        case .body, .bodyStrong: return 22
        case .caption: return 18
        case .overline: return 14
        case .mono: return 20
        case .tipNumber: return 15
        }
    }

    fileprivate var design: UIFontDescriptor.SystemDesign {
        switch self {
        case .displayLarge, .mono, .tipNumber: return .rounded
        default: return .default
        }
    }

    fileprivate var weight: UIFont.Weight {
        switch self {
        case .displayLarge: return .bold
        case .displayMedium, .h1: return .bold
        case .h2, .h3, .bodyStrong, .mono, .tipNumber: return .semibold
        case .body: return .regular
        case .caption: return .regular
        case .overline: return .semibold
        }
    }

    fileprivate var trackingEm: CGFloat {
        switch self {
        case .displayLarge: return -0.02
        case .displayMedium, .h1: return -0.02
        case .h2, .h3: return -0.01
        case .overline: return 0.08
        default: return 0
        }
    }

    fileprivate var relativeStyle: UIFont.TextStyle {
        switch self {
        case .displayLarge: return .largeTitle
        case .displayMedium: return .title1
        case .h1: return .title2
        case .h2: return .title3
        case .h3: return .headline
        case .body, .bodyStrong: return .body
        case .caption: return .subheadline
        case .overline: return .caption2
        case .mono: return .body
        case .tipNumber: return .caption1
        }
    }

    private func uiFont() -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(design) ?? base.fontDescriptor
        let font = UIFont(descriptor: descriptor, size: size)
        return UIFontMetrics(forTextStyle: relativeStyle).scaledFont(for: font)
    }

    var font: Font { Font(uiFont()) }

    fileprivate var tabularFont: Font { Font(uiFont()).monospacedDigit() }

    var tracking: CGFloat { trackingEm * size }

    var lineSpacing: CGFloat {
        max(0, lineHeight - size * 1.25)
    }
}

extension View {
    /// Applies an `AppTextStyle` (font, tracking, line spacing) and, for
    /// numeric styles, tabular/lining figures.
    func appFont(_ style: AppTextStyle, tabularNumbers: Bool = false) -> some View {
        let useTabular = tabularNumbers || style == .mono
        return self
            .font(useTabular ? style.tabularFont : style.font)
            .tracking(L10n.isRightToLeft ? 0 : style.tracking)
            .lineSpacing(style.lineSpacing)
    }
}

extension AppTextStyle: Equatable {}
