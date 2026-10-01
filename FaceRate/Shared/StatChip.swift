import SwiftUI

/// Home dashboard's 3-across stat row — a glass chip with the value in
/// rounded numerals, tinted to the category.
struct StatChip: View {
    let label: String
    let value: String
    let category: ScoreCategory

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(LocalizedStringKey(label)).appFont(.caption).foregroundStyle(AppColors.textSecondary)
            Text(value)
                // A Dynamic Type-scalable text style rather than a fixed size.
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(AppColors.score(for: category))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm12)
        .padding(.vertical, AppSpacing.sm12)
        .glassCard(cornerRadius: AppRadius.md, fill: AppColors.bgSurfaceElevated, shadow: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

#Preview {
    HStack(spacing: AppSpacing.sm12) {
        StatChip(label: L10n.text("Skin"), value: "8.4", category: .skin)
        StatChip(label: L10n.text("Symmetry"), value: "7.9", category: .symmetry)
        StatChip(label: L10n.text("Jawline"), value: "8.0", category: .jawline)
    }
    .padding()
    .background(AppColors.bgPrimary)
}
