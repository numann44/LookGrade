import SwiftUI

/// Renders a Lucide icon bundled as a template vector asset under
/// Assets.xcassets/Icons (DESIGN.md §2.6 — size scale 16/20/24/28, stroke
/// 1.75). Tint with `.foregroundStyle`, matching Lucide's `currentColor`
/// stroke convention.
struct LucideIcon: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Image(name)
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .scaleEffect(x: L10n.isRightToLeft && ["arrow-right", "arrow-left", "chevron-right", "chevron-left"].contains(name) ? -1 : 1, y: 1)
    }
}

#Preview {
    HStack(spacing: AppSpacing.md16) {
        LucideIcon(name: "scan")
        LucideIcon(name: "shield")
        LucideIcon(name: "trash-2")
        LucideIcon(name: "sparkles")
    }
    .foregroundStyle(AppColors.textPrimary)
    .padding()
    .background(AppColors.bgPrimary)
}
