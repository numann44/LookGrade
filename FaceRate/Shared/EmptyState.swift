import SwiftUI

/// DESIGN.md §3.9 — used on Progress (no scans yet) and Tips (all addressed).
struct EmptyState: View {
    let icon: String
    let title: String
    let bodyText: String
    var ctaTitle: String? = nil
    var cta: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.md16) {
            LucideIcon(name: icon, size: 56)
                .foregroundStyle(AppColors.textTertiary)
            Text(title).appFont(.h2).foregroundStyle(AppColors.textPrimary)
            Text(bodyText)
                .appFont(.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            if let ctaTitle {
                PrimaryButton(title: ctaTitle, variant: .outline) { cta?() }
            }
        }
        .padding(AppSpacing.xl24)
    }
}

#Preview {
    EmptyState(icon: "scan", title: L10n.text("No scans yet"), bodyText: L10n.text("Run your first scan to start tracking progress."), ctaTitle: L10n.text("Run a scan")) {}
        .background(AppColors.bgPrimary)
}
