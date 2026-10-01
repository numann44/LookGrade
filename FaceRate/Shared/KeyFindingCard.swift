import SwiftUI

/// DESIGN.md §3.12 — one cell in the Score Report's 2x2 findings grid.
struct KeyFindingCard: View {
    let icon: String
    let title: String
    let bodyText: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs8) {
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(accent)
                .frame(width: 32, height: 32)
                .background(accent.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

            Text(LocalizedStringKey(title)).appFont(.h3).foregroundStyle(AppColors.textPrimary)
            Text(LocalizedStringKey(bodyText)).appFont(.body).foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md16)
        .glassCard()
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm12) {
        KeyFindingCard(icon: "eye", title: L10n.text("Striking Eyes"), bodyText: L10n.text("Exceptional canthal tilt."), accent: AppColors.score(for: .eyes))
        KeyFindingCard(icon: "droplet", title: L10n.text("Hydration Focus"), bodyText: L10n.text("Minor texture variation."), accent: AppColors.score(for: .skin))
    }
    .padding()
    .background(AppColors.bgPrimary)
}
