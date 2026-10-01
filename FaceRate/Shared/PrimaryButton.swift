import SwiftUI

/// Height 54, radius `sm`, full-width by default. Filled = the brand
/// indigo→violet gradient with a soft glow; outline/ghost stay quiet.
enum PrimaryButtonVariant {
    case filled
    case outline
    case ghost
}

struct PrimaryButton: View {
    let title: String
    var variant: PrimaryButtonVariant = .filled
    var leadingIcon: String? = nil
    var isLoading: Bool = false
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: AppSpacing.xs8) {
                if isLoading {
                    ProgressView().tint(foregroundColor)
                } else {
                    if let leadingIcon {
                        LucideIcon(name: leadingIcon, size: 19)
                    }
                    Text(LocalizedStringKey(title)).appFont(.bodyStrong).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
            }
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
        }
        .buttonStyle(PrimaryButtonStyle(variant: variant))
        .disabled(isLoading)
        .opacity(isEnabled ? 1 : 0.4)
    }

    private var foregroundColor: Color {
        variant == .filled ? AppColors.accentOnPrimary : AppColors.textPrimary
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    let variant: PrimaryButtonVariant

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                background(pressed: configuration.isPressed)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                    .shadow(
                        color: variant == .filled ? AppColors.accentGlow.opacity(0.28) : .clear,
                        radius: 8,
                        y: 3
                    )
            }
            .overlay {
                if variant == .outline {
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    @ViewBuilder
    private func background(pressed: Bool) -> some View {
        switch variant {
        case .filled:
            AppColors.accentGradient
                .overlay(Color.black.opacity(pressed ? 0.12 : 0))
        case .outline, .ghost:
            Color.clear
        }
    }
}

#Preview {
    VStack(spacing: AppSpacing.md16) {
        PrimaryButton(title: L10n.text("Run a new scan"), leadingIcon: "scan") {}
        PrimaryButton(title: L10n.text("Continue"), variant: .outline) {}
        PrimaryButton(title: L10n.text("Cancel"), variant: .ghost) {}
        PrimaryButton(title: L10n.text("Loading"), isLoading: true) {}
        PrimaryButton(title: L10n.text("Disabled")) {}.disabled(true)
    }
    .padding()
    .background(AppColors.bgPrimary)
}
