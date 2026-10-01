import SwiftUI

/// FaceRate wordmark + settings cog, with a thin divider below.
struct AppHeader: View {
    var onSettingsTap: (() -> Void)? = nil
    /// Used when the header sits on a modally-presented screen.
    var onClose: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.xs8) {
                if let onClose {
                    Button {
                        Haptics.selection()
                        onClose()
                    } label: {
                        LucideIcon(name: "x", size: 20)
                            .foregroundStyle(AppColors.textPrimary)
                            .frame(width: 28, height: 28)
                            .background(AppColors.bgSurfaceElevated)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(L10n.text("Close"))
                }

                Text("LookGrade").appFont(.h2).foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button {
                    Haptics.selection()
                    onSettingsTap?()
                } label: {
                    LucideIcon(name: "settings", size: 22)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(L10n.text("Settings"))
            }
            .padding(.horizontal, AppSpacing.md16)
            .padding(.vertical, AppSpacing.sm12)

            Rectangle().fill(AppColors.borderMuted).frame(height: 1)
        }
        .background(AppColors.bgPrimary)
    }
}

#Preview {
    VStack {
        AppHeader(onSettingsTap: {})
        Spacer()
    }
    .background(AppColors.bgPrimary)
}
