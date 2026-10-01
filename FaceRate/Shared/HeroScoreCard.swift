import SwiftUI

/// The floating hero on the Score Report: the signature score ring over a
/// glass card, with the coach's "potential" promise beneath it.
struct HeroScoreCard: View {
    let score: Double
    let potentialDelta: Double

    var body: some View {
        VStack(spacing: AppSpacing.md16) {
            ScoreRing(score: score, size: 188, lineWidth: 15)
            PotentialPill(delta: potentialDelta)
        }
        .padding(.horizontal, AppSpacing.xl24)
        .padding(.vertical, AppSpacing.lg20)
        .frame(width: 300)
        .glassCard(cornerRadius: AppRadius.xl, fill: AppColors.bgSurfaceHigh)
    }
}

/// "↑ +0.4 potential" — the coach's promise, in the success tone.
struct PotentialPill: View {
    let delta: Double
    var body: some View {
        HStack(spacing: 5) {
            LucideIcon(name: "trending-up", size: 14)
            Text(L10n.text("+\(String(format: "%.1f", locale: L10n.locale, delta)) potential")).appFont(.caption).lineLimit(1).fixedSize()
        }
        .foregroundStyle(AppColors.stateSuccess)
        .padding(.horizontal, AppSpacing.sm12)
        .padding(.vertical, 6)
        .background(AppColors.stateSuccess.opacity(0.14), in: Capsule())
    }
}

#Preview {
    HeroScoreCard(score: 8.2, potentialDelta: 0.4)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bgPrimary)
}
