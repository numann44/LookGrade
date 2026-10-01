import SwiftUI

/// One category row on the Score Report: a rounded gradient meter with a
/// soft tinted glow and a rounded-numeral value. Fill animates on first
/// reveal (900ms, 60ms stagger). Value exposed via Semantics.
struct ScoreBar: View {
    let category: ScoreCategory
    let value: Double // 0...10
    var staggerIndex: Int = 0

    @State private var fraction: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Widths scale with Dynamic Type so "Skin Quality" / the value don't clip
    // at large text sizes while rows still line up.
    @ScaledMetric(relativeTo: .body) private var labelWidth: CGFloat = 82
    @ScaledMetric(relativeTo: .body) private var valueWidth: CGFloat = 34

    private var color: Color { AppColors.score(for: category) }

    var body: some View {
        HStack(spacing: AppSpacing.sm12) {
            Text(category.label)
                .appFont(.body)
                .foregroundStyle(AppColors.textSecondary)
                .frame(width: labelWidth, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.bgSurfaceElevated)
                    Capsule()
                        .fill(AppColors.gradient(for: category))
                        .frame(width: max(9, geo.size.width * fraction))
                        .shadow(color: color.opacity(0.45), radius: 5)
                }
            }
            .frame(height: 9)

            Text(String(format: "%.1f", locale: L10n.locale, value))
                .appFont(.mono, tabularNumbers: true)
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: valueWidth, alignment: .trailing)
        }
        .onAppear {
            if reduceMotion {
                fraction = CGFloat(value / 10)
            } else {
                withAnimation(.easeOut(duration: 0.9).delay(Double(staggerIndex) * 0.06)) {
                    fraction = CGFloat(value / 10)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.label)
        .accessibilityValue(L10n.text("\(String(format: "%.1f", locale: L10n.locale, value)) out of 10"))
    }
}

#Preview {
    VStack(spacing: AppSpacing.md16) {
        ForEach(Array(ScoreCategory.allCases.enumerated()), id: \.offset) { i, cat in
            ScoreBar(category: cat, value: Double.random(in: 6.5...9.4), staggerIndex: i)
        }
    }
    .padding()
    .background(AppColors.bgPrimary)
}
