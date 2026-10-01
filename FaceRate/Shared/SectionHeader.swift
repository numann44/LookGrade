import SwiftUI

/// DESIGN.md §3.16.
struct SectionHeader: View {
    let title: String
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            Text(LocalizedStringKey(title)).appFont(.h2).foregroundStyle(AppColors.textPrimary)
            Spacer()
            if let actionLabel {
                Button(LocalizedStringKey(actionLabel)) { action?() }
                    .appFont(.caption)
                    .foregroundStyle(AppColors.accentPrimary)
            }
        }
    }
}

#Preview {
    SectionHeader(title: L10n.text("Opportunities"), actionLabel: L10n.text("View All")) {}
        .padding()
        .background(AppColors.bgPrimary)
}
