import SwiftUI

/// DESIGN.md §3.3. Accent rotates jawline → skin → symmetry across rows;
/// callers pass the row index and this maps it to that rotation.
struct TipCard: View {
    let number: Int
    let title: String
    let bodyText: String
    let icon: String
    let accentIndex: Int
    var actionLabel: String? = nil

    private static let accentRotation: [ScoreCategory] = [.jawline, .skin, .symmetry]
    private var accentColor: Color {
        AppColors.score(for: Self.accentRotation[accentIndex % Self.accentRotation.count])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs8) {
            HStack(alignment: .top, spacing: AppSpacing.sm12) {
                Text(String(format: "%02d", locale: L10n.locale, number))
                    .appFont(.tipNumber)
                    .foregroundStyle(accentColor)
                    .frame(width: 24, height: 20)
                    .background(accentColor.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title)).appFont(.h3).foregroundStyle(AppColors.textPrimary)
                    Text(LocalizedStringKey(bodyText)).appFont(.body).foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 0)

                LucideIcon(name: icon, size: 20)
                    .foregroundStyle(accentColor)
            }

            if let actionLabel {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(actionLabel)).appFont(.caption)
                    LucideIcon(name: "chevron-right", size: 14)
                }
                .foregroundStyle(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm12)
                .padding(.vertical, AppSpacing.xs8)
                .background(AppColors.bgSurfaceElevated)
                .clipShape(Capsule())
            }
        }
        .padding(AppSpacing.md16)
        .glassCard()
    }
}

#Preview {
    VStack(spacing: AppSpacing.sm12) {
        TipCard(number: 1, title: L10n.text("Jawline Routine"), bodyText: L10n.text("Targeted exercises can sharpen lower-face definition."), icon: "trending-up", accentIndex: 0, actionLabel: L10n.text("View routine"))
        TipCard(number: 2, title: L10n.text("Hydration Focus"), bodyText: L10n.text("Minor texture variation detected in the cheeks."), icon: "droplet", accentIndex: 1)
    }
    .padding()
    .background(AppColors.bgPrimary)
}
