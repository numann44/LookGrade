import SwiftUI
import UIKit

struct ScoreReportScreen: View {
    let result: ScanResult
    var onSeeTips: () -> Void
    var onSettings: () -> Void
    var onClose: (() -> Void)? = nil
    /// First-scan previews retain the real report layout and photo while
    /// concealing score-bearing detail until Pro is active.
    var isLockedPreview: Bool = false
    var showsBottomAction: Bool = true

    @State private var shareCard: Image?

    var body: some View {
        ZStack {
            JoyColors.canvas.ignoresSafeArea()
            QuietReportBackdrop()

            VStack(spacing: 0) {
                RefinedReportHeader(
                    shareCard: shareCard,
                    onSettings: {
                        AppAnalytics.shared.track(.reportAction, ["action": "settings"])
                        onSettings()
                    },
                    onClose: onClose.map { close in {
                        AppAnalytics.shared.track(.reportAction, ["action": "close"])
                        close()
                    } }
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        reportIntro

                        if !isLockedPreview {
                            MiroCompanion(
                                message: L10n.text("Here’s your starting point. Let’s turn these insights into progress."),
                                expression: .grin, size: 120
                            )
                            .padding(.top, 12)
                        }

                        if let image = capturedImage {
                            RefinedReportPhoto(image: image, isLocked: isLockedPreview)
                                .padding(.top, isLockedPreview ? 12 : 20)
                        }

                        RefinedReportHero(
                            score: result.overallScore,
                            potentialDelta: result.potentialDelta,
                            capturedAt: result.input.capturedAt,
                            isLocked: isLockedPreview
                        )
                        .padding(.top, isLockedPreview ? 12 : 18)
                        .analyticsSection("overall")

                        reportSectionHeader(title: L10n.text("Your scores"), detail: L10n.text("\(result.categories.count) AREAS"))
                            .padding(.top, isLockedPreview ? 22 : 30)

                        VStack(spacing: 4) {
                            ForEach(Array(result.categories.enumerated()), id: \.offset) { index, score in
                                ReportScoreRow(
                                    category: score.category,
                                    value: score.value,
                                    staggerIndex: index,
                                    isLocked: isLockedPreview
                                )
                                .analyticsSection("category_\(score.category.rawValue)")
                            }
                        }
                        .padding(10)
                        .background(JoyColors.surface.opacity(0.90), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(JoyColors.ink.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.top, 14)
                        .accessibilityHidden(isLockedPreview)

                        if result.faceShape != nil || result.undertone != nil {
                            HStack(spacing: 10) {
                                if let shape = result.faceShape {
                                    ProfileTile(icon: "scan", label: L10n.text("FACE SHAPE"), value: L10n.lookup(shape), accent: JoyColors.lemon)
                                }
                                if let tone = result.undertone {
                                    ProfileTile(icon: "droplet", label: L10n.text("UNDERTONE"), value: L10n.lookup(tone), accent: JoyColors.mint)
                                }
                            }
                            .padding(.top, 12)
                            .blur(radius: isLockedPreview ? 7 : 0)
                            .accessibilityHidden(isLockedPreview)
                        }

                        reportSectionHeader(title: L10n.text("Key findings"), detail: L10n.text("\(result.findings.count) NOTES"))
                            .padding(.top, 30)
                            .analyticsSection("findings")

                        VStack(spacing: 10) {
                            ForEach(result.findings) { finding in
                                RefinedFindingRow(
                                    icon: iconFor(finding.category),
                                    title: L10n.lookup(finding.title),
                                    bodyText: L10n.lookup(finding.body),
                                    accent: reportAccent(for: finding.category)
                                )
                            }
                        }
                        .padding(.top, 14)
                        .blur(radius: isLockedPreview ? 9 : 0)
                        .accessibilityHidden(isLockedPreview)

                        HStack(alignment: .top, spacing: 9) {
                            LucideIcon(name: "info", size: 15)
                                .foregroundStyle(JoyColors.muted)
                                .padding(.top, 1)

                            Text(L10n.text("A heuristic guide for tracking your own features over time — not a medical or attractiveness assessment."))
                                .font(.system(.caption, design: .rounded, weight: .semibold))
                                .foregroundStyle(JoyColors.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                    }
                    .padding(.horizontal, 18)
                }
                .analyticsScrollViewport(isLockedPreview ? "locked_report" : "report")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showsBottomAction {
                ReportTipsButton(action: {
                    AppAnalytics.shared.track(.reportAction, ["action": "see_tips"])
                    onSeeTips()
                })
            }
        }
        .environment(\.locale, L10n.locale)
        .analyticsScreen(isLockedPreview ? "locked_report" : "report")
        .onAppear {
            if !isLockedPreview { renderShareCard() }
        }
    }

    private var capturedImage: UIImage? {
        let path = ScanImageStore.currentPath(forStoredPath: result.input.imagePath)
        if !path.isEmpty, let image = UIImage(contentsOfFile: path) { return image }
        // History reports and purged capture caches still have a local saved
        // thumbnail. This also preserves the onboarding photo after updates.
        return ScanPhotoLibrary.image(for: ScanHistoryEntry.id(forCapturedAt: result.input.capturedAt))
    }

    private var reportIntro: some View {
        VStack(alignment: .leading, spacing: isLockedPreview ? 5 : 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(JoyColors.coral)
                    .frame(width: 8, height: 8)

                Text(L10n.text("YOUR FACE REPORT"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(L10n.isRightToLeft ? 0 : 1.4)
                    .foregroundStyle(JoyColors.muted)
            }

            Text(L10n.text("Your score, decoded."))
                .font(.system(size: isLockedPreview ? 28 : 34, weight: .black, design: .rounded))
                .tracking(L10n.isRightToLeft ? 0 : -1.0)
                .foregroundStyle(JoyColors.ink)

            if !isLockedPreview {
                Text(L10n.text("A clear look at every detail from your latest scan."))
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .foregroundStyle(JoyColors.muted)
            }
        }
        .padding(.top, isLockedPreview ? 10 : 18)
    }

    private func reportSectionHeader(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)

            Spacer()

            Text(detail)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(L10n.isRightToLeft ? 0 : 0.8)
                .foregroundStyle(JoyColors.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(JoyColors.surface.opacity(0.82), in: Capsule())
                .overlay(Capsule().stroke(JoyColors.ink.opacity(0.10), lineWidth: 1))
        }
    }

    @MainActor
    private func renderShareCard() {
        guard shareCard == nil else { return }
        let renderer = ImageRenderer(content: ShareCardView(result: result)
            .environment(\.locale, L10n.locale)
            .environment(\.layoutDirection, L10n.isRightToLeft ? .rightToLeft : .leftToRight))
        renderer.scale = 3
        if let ui = renderer.uiImage {
            shareCard = Image(uiImage: ui)
        }
    }

    private func iconFor(_ category: ScoreCategory) -> String {
        switch category {
        case .symmetry: return "scale"
        case .skin: return "droplet"
        case .jawline: return "square"
        case .eyes: return "eye"
        case .lips: return "smile"
        case .nose: return "move"
        case .tone: return "sun"
        case .harmony: return "scan"
        }
    }
}

private func reportAccent(for category: ScoreCategory) -> Color {
    switch category {
    case .symmetry: return JoyColors.sky
    case .skin: return JoyColors.mint
    case .jawline: return JoyColors.orange
    case .eyes: return JoyColors.sky
    case .lips: return JoyColors.coral
    case .nose: return JoyColors.lemon
    case .tone: return JoyColors.mint
    case .harmony: return JoyColors.lemon
    }
}

private struct RefinedReportHeader: View {
    let shareCard: Image?
    let onSettings: () -> Void
    let onClose: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if let onClose {
                Button {
                    Haptics.selection()
                    onClose()
                } label: {
                    LucideIcon(name: "x", size: 18)
                        .foregroundStyle(JoyColors.ink)
                        .frame(width: 36, height: 36)
                        .background(JoyColors.surface.opacity(0.88), in: Circle())
                        .overlay(Circle().stroke(JoyColors.ink.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Close"))
            } else {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(JoyColors.surface)
                        .overlay(Circle().stroke(JoyColors.ink.opacity(0.16), lineWidth: 1.2))

                    LucideIcon(name: "chart-line", size: 18)
                        .foregroundStyle(JoyColors.ink)

                    Circle()
                        .fill(JoyColors.coral)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(JoyColors.ink.opacity(0.24), lineWidth: 1))
                        .offset(x: 1, y: -1)
                }
                .frame(width: 36, height: 36)
            }

            Text("LookGrade")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)

            Spacer()

            if let shareCard {
                ShareLink(
                    item: shareCard,
                    preview: SharePreview(L10n.text("My LookGrade score"), image: shareCard)
                ) {
                    LucideIcon(name: "arrow-right", size: 17)
                        .rotationEffect(.degrees(-90))
                        .foregroundStyle(JoyColors.ink)
                        .frame(width: 38, height: 38)
                        .background(JoyColors.surface.opacity(0.88), in: Circle())
                        .overlay(Circle().stroke(JoyColors.ink.opacity(0.14), lineWidth: 1))
                }
                .accessibilityLabel(L10n.text("Share your score"))
                .simultaneousGesture(TapGesture().onEnded {
                    AppAnalytics.shared.track(.reportAction, ["action": "share_requested"])
                })
            }

            Button {
                Haptics.selection()
                onSettings()
            } label: {
                LucideIcon(name: "settings", size: 20)
                    .foregroundStyle(JoyColors.ink)
                    .frame(width: 38, height: 38)
                    .background(JoyColors.surface.opacity(0.88), in: Circle())
                    .overlay(Circle().stroke(JoyColors.ink.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.text("Settings"))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(JoyColors.canvas.opacity(0.94))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(JoyColors.ink.opacity(0.07))
                .frame(height: 1)
        }
    }
}

private struct RefinedReportPhoto: View {
    let image: UIImage
    let isLocked: Bool

    var body: some View {
        ZStack {
            JoyColors.surface.opacity(0.9)

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: isLocked ? .fit : .fill)
                .frame(maxWidth: .infinity, maxHeight: isLocked ? 280 : 220)
                .clipped()
        }
        .frame(height: isLocked ? 280 : 220)
        .frame(maxWidth: .infinity)
            .overlay(alignment: .bottomLeading) {
                LinearGradient(
                    colors: [.clear, JoyColors.ink.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                HStack(spacing: 7) {
                    LucideIcon(name: "shield", size: 14)
                    Text(L10n.text("Analyzed on device"))
                }
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(Color.white)
                .padding(15)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(JoyColors.ink.opacity(0.14), lineWidth: 1)
            )
            .accessibilityLabel(L10n.text("Photo from this scan"))
    }
}

private struct RefinedReportHero: View {
    let score: Double
    let potentialDelta: Double
    let capturedAt: Date
    let isLocked: Bool

    var body: some View {
        HStack(spacing: 15) {
            RefinedReportScoreRing(score: score, isLocked: isLocked)

            Rectangle()
                .fill(JoyColors.ink.opacity(0.08))
                .frame(width: 1, height: 118)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("POTENTIAL"))
                    .font(.system(.caption2, design: .rounded, weight: .black))
                    .tracking(L10n.isRightToLeft ? 0 : 1.0)
                    .foregroundStyle(JoyColors.muted)

                Text("+\(String(format: "%.1f", locale: L10n.locale, potentialDelta))")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .tracking(L10n.isRightToLeft ? 0 : -0.7)
                    .foregroundStyle(JoyColors.ink)
                    .blur(radius: isLocked ? 7 : 0)

                Text(L10n.text("points within reach"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(JoyColors.muted)

                HStack(spacing: 5) {
                    Circle()
                        .fill(JoyColors.mint)
                        .frame(width: 7, height: 7)
                    Text(capturedAt.formatted(
                        .dateTime
                            .locale(L10n.locale)
                            .month(.abbreviated)
                            .day()
                    ))
                }
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundStyle(JoyColors.muted)
                .padding(.top, 3)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .background(JoyColors.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.15), lineWidth: 1.1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct RefinedReportScoreRing: View {
    let score: Double
    let isLocked: Bool

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var target: CGFloat {
        CGFloat(max(0, min(10, score)) / 10)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(JoyColors.ink.opacity(0.08), lineWidth: 11)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    JoyColors.coral,
                    style: StrokeStyle(lineWidth: 11, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(L10n.text("OVERALL"))
                    .font(.system(.caption2, design: .rounded, weight: .black))
                    .tracking(L10n.isRightToLeft ? 0 : 1.0)
                    .foregroundStyle(JoyColors.muted)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", locale: L10n.locale, score))
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .blur(radius: isLocked ? 11 : 0)
                        .opacity(isLocked ? 0.48 : 1)
                    Text("/10")
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .foregroundStyle(JoyColors.muted)
                }
                .foregroundStyle(JoyColors.ink)
            }
        }
        .frame(width: 142, height: 142)
        .onAppear {
            if reduceMotion {
                progress = target
            } else {
                withAnimation(.easeOut(duration: 0.85).delay(0.08)) {
                    progress = target
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("Overall reading"))
        .accessibilityValue(isLocked ? L10n.text("Locked until Pro") : L10n.text("\(String(format: "%.1f", locale: L10n.locale, score)) out of 10"))
    }
}

private struct ReportScoreRow: View {
    let category: ScoreCategory
    let value: Double
    let staggerIndex: Int
    let isLocked: Bool

    @State private var fraction: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color { reportAccent(for: category) }

    var body: some View {
        HStack(spacing: 11) {
            LucideIcon(name: icon, size: 16)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 38, height: 38)
                .background(accent.opacity(0.46), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                Text(category.label)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(JoyColors.ink)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(JoyColors.ink.opacity(0.07))
                        Capsule()
                            .fill(accent.opacity(0.88))
                            .frame(width: max(8, geometry.size.width * fraction))
                    }
                }
                .frame(height: 6)
                .blur(radius: isLocked ? 8 : 0)
                .opacity(isLocked ? 0.56 : 1)
            }

            Text(String(format: "%.1f", locale: L10n.locale, value))
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .monospacedDigit()
                .foregroundStyle(JoyColors.ink)
                .frame(width: 34, alignment: .trailing)
                .blur(radius: isLocked ? 10 : 0)
                .opacity(isLocked ? 0.43 : 1)
        }
        .padding(.horizontal, 7)
        .frame(minHeight: 58)
        .onAppear {
            let target = CGFloat(max(0, min(10, value)) / 10)
            if reduceMotion {
                fraction = target
            } else {
                withAnimation(.easeOut(duration: 0.7).delay(Double(staggerIndex) * 0.045)) {
                    fraction = target
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(category.label)
        .accessibilityValue(L10n.text("\(String(format: "%.1f", locale: L10n.locale, value)) out of 10"))
    }

    private var icon: String {
        switch category {
        case .symmetry: return "scale"
        case .skin: return "droplet"
        case .jawline: return "square"
        case .eyes: return "eye"
        case .lips: return "smile"
        case .nose: return "move"
        case .tone: return "sun"
        case .harmony: return "scan"
        }
    }
}

private struct RefinedFindingRow: View {
    let icon: String
    let title: String
    let bodyText: String
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 40, height: 40)
                .background(accent.opacity(0.48), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)

                Text(bodyText)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(JoyColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(15)
        .background(JoyColors.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.11), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct ReportTipsButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 9) {
                LucideIcon(name: "lightbulb", size: 20)
                Text(L10n.text("See your tips"))
                    .font(.system(.headline, design: .rounded, weight: .black))
                Spacer()
                LucideIcon(name: "arrow-right", size: 19)
            }
            .foregroundStyle(JoyColors.ink)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(JoyColors.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(JoyColors.ink.opacity(0.30), lineWidth: 1.2)
            )
        }
        .buttonStyle(ReportPressStyle())
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(JoyColors.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(JoyColors.ink.opacity(0.10))
                .frame(height: 1)
        }
    }
}

private struct QuietReportBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(JoyColors.sky.opacity(0.08))
                .frame(width: 200, height: 200)
                .position(x: geometry.size.width + 55, y: 160)

            Circle()
                .fill(JoyColors.lemon.opacity(0.05))
                .frame(width: 180, height: 180)
                .position(x: -45, y: geometry.size.height * 0.68)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct ReportPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}

/// Compact derived-descriptor tile (face shape / undertone) on the report.
private struct ProfileTile: View {
    let icon: String
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 38, height: 38)
                .background(accent.opacity(0.48), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(.caption2, design: .rounded, weight: .black))
                    .tracking(L10n.isRightToLeft ? 0 : 0.7)
                    .foregroundStyle(JoyColors.muted)
                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
        .background(JoyColors.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.11), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// The off-screen card rendered to an image for sharing — branded, with the
/// score ring and top categories. Never appears in the live UI.
private struct ShareCardView: View {
    let result: ScanResult

    private var topThree: [CategoryScore] {
        Array(result.categories.sorted { $0.value > $1.value }.prefix(3))
    }

    var body: some View {
        VStack(spacing: AppSpacing.lg20) {
            HStack(spacing: AppSpacing.xs8) {
                LucideIcon(name: "scan-face", size: 18).foregroundStyle(AppColors.accentPrimary)
                Text("LookGrade").appFont(.h3).foregroundStyle(AppColors.textPrimary)
            }
            ScoreRing(score: result.overallScore, size: 150, lineWidth: 14, caption: L10n.text("OVERALL"))
            HStack(spacing: AppSpacing.sm12) {
                ForEach(topThree, id: \.category) { cs in
                    VStack(spacing: 3) {
                        Text(String(format: "%.1f", locale: L10n.locale, cs.value))
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(AppColors.score(for: cs.category))
                        Text(cs.category.label).appFont(.caption).foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(L10n.text("Analyzed on device • facerate.app"))
                .appFont(.caption).foregroundStyle(AppColors.textTertiary)
        }
        .padding(AppSpacing.xxl32)
        .frame(width: 380)
        .background(AppColors.bgPrimary)
    }
}
