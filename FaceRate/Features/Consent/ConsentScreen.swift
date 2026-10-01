import SwiftUI

private enum ConsentPalette {
    static let background = Color(rgb: 0x111212)
    static let surface = Color(rgb: 0x191A1A)
    static let surfaceRaised = Color(rgb: 0x212222)
    static let text = Color(rgb: 0xF5F5F1)
    static let muted = Color(rgb: 0x999B98)
    static let faint = Color(rgb: 0x626461)
    static let line = Color.white.opacity(0.10)
    static let blue = Color(rgb: 0x3D8BFF)
}

/// Premium privacy agreement immediately before the user's first real scan.
struct ConsentScreen: View {
    var onBack: (() -> Void)? = nil
    var onContinue: () -> Void

    @State private var agreed = false

    var body: some View {
        ZStack {
            ConsentPalette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        hero
                        promises
                            .padding(.top, 28)
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 22)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { actionArea }
        .preferredColorScheme(.dark)
        .analyticsScreen("privacy_agreement")
        .onChange(of: agreed) { _, value in
            AppAnalytics.shared.track(.consentAction, ["action": "agreement_toggle", "selected": value])
        }
    }

    private var header: some View {
        HStack {
            if let onBack {
                Button {
                    Haptics.selection()
                    AppAnalytics.shared.track(.consentAction, ["action": "back"])
                    onBack()
                } label: {
                    LucideIcon(name: "chevron-left", size: 21)
                        .foregroundStyle(ConsentPalette.text)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Back"))
            } else {
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(ConsentPalette.surfaceRaised)
                        .frame(width: 28, height: 28)
                        .overlay {
                            LucideIcon(name: "scan-face", size: 15)
                                .foregroundStyle(.white)
                        }
                    Text("LookGrade")
                        .appFont(.bodyStrong)
                        .foregroundStyle(ConsentPalette.text)
                }
                .frame(height: 44)
            }

            Spacer()

            HStack(spacing: 6) {
                LucideIcon(name: "lock", size: 12)
                Text(L10n.text("PRIVATE"))
            }
            .appFont(.overline)
            .foregroundStyle(ConsentPalette.muted)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(ConsentPalette.surface, in: Capsule())
            .overlay { Capsule().strokeBorder(ConsentPalette.line, lineWidth: 1) }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 15) {
            MiroCompanion(
                message: agreed ? L10n.text("You’re in control. Let’s take the next step.") : L10n.text("I’m here for you. Take a moment to see how your photo stays private."),
                expression: agreed ? .grin : .curious,
                size: 158
            )

            Text(L10n.text("Before your first scan"))
                .appFont(.overline)
                .foregroundStyle(ConsentPalette.blue)

            Text(L10n.text("Your face stays yours."))
                .font(.system(size: 28, weight: .bold))
                .tracking(L10n.isRightToLeft ? 0 : -1.05)
                .foregroundStyle(ConsentPalette.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.text("LookGrade analyzes your photo on this device. You stay in control of the image and every result."))
                .appFont(.body)
                .foregroundStyle(ConsentPalette.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 30)
    }

    private var promises: some View {
        VStack(spacing: 10) {
            ConsentPromiseRow(
                icon: "smartphone",
                title: L10n.text("Processed on your phone"),
                detail: L10n.text("Face analysis runs locally on this device.")
            )
            ConsentPromiseRow(
                icon: "ban",
                title: L10n.text("Never sold or shared"),
                detail: L10n.text("Your face data is not used for advertising.")
            )
            ConsentPromiseRow(
                icon: "trash-2",
                title: L10n.text("Delete whenever you want"),
                detail: L10n.text("Remove saved scans and history in Settings.")
            )
        }
    }

    private var agreement: some View {
        Button {
            Haptics.selection()
            withAnimation(.easeOut(duration: 0.18)) {
                agreed.toggle()
            }
        } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(agreed ? ConsentPalette.text : ConsentPalette.surfaceRaised)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(agreed ? ConsentPalette.text : ConsentPalette.line, lineWidth: 1)
                    if agreed {
                        LucideIcon(name: "check", size: 15)
                            .foregroundStyle(ConsentPalette.background)
                    }
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.text("I understand and agree"))
                        .appFont(.bodyStrong)
                        .foregroundStyle(ConsentPalette.text)
                    Text(L10n.text("Required before camera access"))
                        .appFont(.caption)
                        .foregroundStyle(ConsentPalette.faint)
                }

                Spacer()
            }
            .padding(15)
            .background(ConsentPalette.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(agreed ? Color.white.opacity(0.32) : ConsentPalette.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.text("I understand and agree"))
        .accessibilityValue(agreed ? L10n.text("Checked") : L10n.text("Not checked"))
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            agreement

            Button {
                Haptics.light()
                AppAnalytics.shared.track(.consentAction, ["action": "continue"])
                onContinue()
            } label: {
                Text(L10n.text("Continue to camera"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ConsentPalette.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(ConsentPalette.text, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!agreed)
            .opacity(agreed ? 1 : 0.34)

            Text(L10n.text("You can review these controls later in Settings"))
                .appFont(.caption)
                .foregroundStyle(ConsentPalette.faint)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 9)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(ConsentPalette.line).frame(height: 1)
        }
    }
}

private struct ConsentPromiseRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(ConsentPalette.surfaceRaised)
                .frame(width: 44, height: 44)
                .overlay {
                    LucideIcon(name: icon, size: 19)
                        .foregroundStyle(ConsentPalette.text)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(.bodyStrong)
                    .foregroundStyle(ConsentPalette.text)
                Text(detail)
                    .appFont(.caption)
                    .foregroundStyle(ConsentPalette.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(ConsentPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(ConsentPalette.line, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ConsentAmbientGlow: View {
    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(AppColors.accentPrimary.opacity(0.10))
                .frame(width: 270, height: 270)
                .blur(radius: 6)
                .offset(x: proxy.size.width - 150, y: -120)

            Circle()
                .fill(AppColors.score(for: .skin).opacity(0.05))
                .frame(width: 220, height: 220)
                .offset(x: -130, y: proxy.size.height * 0.58)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

#Preview {
    ConsentScreen(onContinue: {})
}
