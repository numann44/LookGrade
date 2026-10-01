import SwiftUI

/// A quiet opening composition. It deliberately avoids a fake score or face
/// scanner: the first screen is an invitation, not a promise of a result.
struct OnboardingIntroVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var drifting = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [AppColors.bgSurfaceElevated, AppColors.bgSurface.opacity(0.74)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.09), AppColors.borderMuted],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }

            Circle()
                .fill(AppColors.accentPrimary.opacity(0.10))
                .frame(width: 192, height: 192)
                .blur(radius: 18)
                .offset(x: -28, y: -8)

            VStack(spacing: 15) {
                HStack(spacing: 10) {
                    IntroPebble(color: AppColors.score(for: .skin), width: 43, height: 43)
                        .offset(y: drifting ? -7 : 4)
                    IntroPebble(color: AppColors.accentPrimary, width: 76, height: 58)
                        .offset(y: drifting ? 4 : -5)
                    IntroPebble(color: AppColors.score(for: .symmetry), width: 43, height: 43)
                        .offset(y: drifting ? -3 : 6)
                }

                Capsule()
                    .fill(AppColors.borderSubtle)
                    .frame(width: 134, height: 2)
                    .overlay(alignment: .leading) {
                        Circle()
                            .fill(AppColors.textPrimary)
                            .frame(width: 9, height: 9)
                            .offset(x: drifting ? 125 : 0)
                            .animation(
                                reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true),
                                value: drifting
                            )
                    }

                Text(L10n.text("A FIRST LOOK"))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(L10n.isRightToLeft ? 0 : 1.6)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .scaleEffect(appeared ? 1 : 0.90)
            .opacity(appeared ? 1 : 0)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 24, y: 15)
        .onAppear {
            drifting = true
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .premiumEase.delay(0.12)) {
                appeared = true
            }
        }
        .accessibilityHidden(true)
    }
}

private struct IntroPebble: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: min(width, height) * 0.38, style: .continuous)
            .fill(color.opacity(0.88))
            .frame(width: width, height: height)
            .overlay {
                RoundedRectangle(cornerRadius: min(width, height) * 0.38, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
            }
    }
}

struct OnboardingMoodVisual: View {
    let value: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.accentPrimary.opacity(0.08))
                .frame(width: 116, height: 116)

            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(AppColors.borderSubtle, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(90))

            Circle()
                .trim(from: 0.12, to: 0.12 + 0.76 * value)
                .stroke(AppColors.accentGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(90))
                .animation(.easeOut(duration: 0.25), value: value)

            LucideIcon(name: value > 0.66 ? "trending-up" : value > 0.33 ? "sparkles" : "scan")
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 44, height: 44)
                .background(AppColors.bgSurfaceHigh, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .id(Int(value * 3))
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.38, dampingFraction: 0.78), value: Int(value * 3))
        }
        .accessibilityHidden(true)
    }
}

struct OnboardingBuildVisual: View {
    let progress: Double
    let isComplete: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.accentPrimary.opacity(isComplete ? 0.11 : 0.06))
                .frame(width: 176, height: 176)
                .blur(radius: isComplete ? 8 : 2)
                .animation(.easeOut(duration: 0.45), value: isComplete)

            Circle()
                .strokeBorder(AppColors.borderMuted, lineWidth: 1)
                .frame(width: 160, height: 160)

            Circle()
                .trim(from: 0, to: max(progress, 0.035))
                .stroke(AppColors.accentGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(-90))
                .animation(.premiumEase, value: progress)

            if !isComplete {
                Circle()
                    .trim(from: 0.05, to: 0.22)
                    .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 136, height: 136)
                    .rotationEffect(.degrees(rotating ? 360 : 0))
                    .animation(
                        reduceMotion ? nil : .linear(duration: 1.7).repeatForever(autoreverses: false),
                        value: rotating
                    )
            }

            VStack(spacing: 6) {
                if isComplete {
                    Circle()
                        .fill(AppColors.accentPrimary)
                        .frame(width: 62, height: 62)
                        .overlay {
                            LucideIcon(name: "check", size: 29)
                                .foregroundStyle(AppColors.bgPrimary)
                        }
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text(progress.formatted(.percent.precision(.fractionLength(0)).locale(L10n.locale)))
                        .font(.system(size: 31, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textPrimary)
                    Text(L10n.text("PERSONALIZING"))
                        .appFont(.overline)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .onAppear { rotating = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isComplete ? L10n.text("Profile complete") : L10n.text("Personalizing profile, \(Int(progress * 100)) percent"))
    }
}

struct OnboardingPrivacyVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 31, style: .continuous)
                .fill(AppColors.bgSurface)
                .frame(width: 118, height: 174)
                .overlay {
                    RoundedRectangle(cornerRadius: 31, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(AppColors.borderSubtle)
                        .frame(width: 40, height: 5)
                        .padding(.top, 12)
                }

            Circle()
                .fill(AppColors.accentPrimary.opacity(0.12))
                .frame(width: 82, height: 82)

            Circle()
                .strokeBorder(AppColors.accentPrimary.opacity(0.32), lineWidth: 1)
                .frame(width: 62, height: 62)

            LucideIcon(name: "shield", size: 31)
                .foregroundStyle(AppColors.accentPrimary)

            PrivacyChip(icon: "lock", text: L10n.text("LOCAL ONLY"))
                .offset(x: -76, y: -59)
                .offset(x: appeared ? 0 : 12)
                .opacity(appeared ? 1 : 0)

            PrivacyChip(icon: "check", text: L10n.text("YOU CONTROL IT"))
                .offset(x: 76, y: 59)
                .offset(x: appeared ? 0 : -12)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .premiumEase.delay(0.12)) {
                appeared = true
            }
        }
        .accessibilityHidden(true)
    }
}

struct OnboardingReadyVisual: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.accentPrimary.opacity(pulse ? 0.05 : 0.13))
                .frame(width: pulse ? 178 : 146, height: pulse ? 178 : 146)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true),
                    value: pulse
                )

            Circle()
                .strokeBorder(AppColors.accentPrimary.opacity(0.26), lineWidth: 1)
                .frame(width: 128, height: 128)
                .scaleEffect(appeared ? 1 : 0.72)

            Circle()
                .fill(AppColors.accentGradient)
                .frame(width: 82, height: 82)
                .overlay {
                    LucideIcon(name: "check", size: 36)
                        .foregroundStyle(Color.white)
                }
                .shadow(color: AppColors.accentGlow, radius: 24)
                .scaleEffect(appeared ? 1 : 0.55)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            pulse = true
            withAnimation(reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.62, dampingFraction: 0.7)) {
                appeared = true
            }
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
                    Haptics.success()
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct IntroMetricChip: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 7) {
            Text(label)
                .appFont(.overline)
                .foregroundStyle(AppColors.textTertiary)
            Text(value)
                .appFont(.mono, tabularNumbers: true)
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
    }
}

private struct PrivacyChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            LucideIcon(name: icon, size: 13)
            Text(text).appFont(.overline)
        }
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, 11)
        .frame(height: 32)
        .background(AppColors.bgSurfaceHigh.opacity(0.96), in: Capsule())
        .overlay(Capsule().strokeBorder(AppColors.borderSubtle, lineWidth: 1))
    }
}

private struct IntroScanBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let length: CGFloat = 24
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        return path
    }
}

private struct PremiumGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
            var path = Path()
            stride(from: CGFloat(0), through: size.width, by: spacing).forEach { x in
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            stride(from: CGFloat(0), through: size.height, by: spacing).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(Color.white.opacity(0.018)), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    VStack(spacing: 20) {
        OnboardingIntroVisual().frame(height: 280)
        OnboardingBuildVisual(progress: 0.66, isComplete: false).frame(height: 190)
    }
    .padding()
    .background(AppColors.bgPrimary)
}
