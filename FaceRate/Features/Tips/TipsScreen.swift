import SwiftUI

struct TipsScreen: View {
    @Environment(ScanHistoryModel.self) private var history
    @Environment(LastResultModel.self) private var lastResult
    @Environment(AppRouter.self) private var router

    private var hasScan: Bool { !history.entries.isEmpty }

    /// Ascending by score — weakest category first, matching tips_screen.dart.
    private var tips: [PersonalizedTip] {
        (lastResult.result?.categories ?? [])
            .sorted { $0.value < $1.value }
            .map { TipBuilder.forScore($0.category, $0.value) }
    }

    var body: some View {
        ZStack {
            JoyColors.canvas.ignoresSafeArea()
            QuietTipsBackdrop()

            VStack(spacing: 0) {
                RefinedTipsHeader(onSettings: { router.select(.profile) })

                if !hasScan {
                    EmptyTipsView { router.startScanFlow() }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            tipsIntro

                            HStack(alignment: .firstTextBaseline) {
                                Text(L10n.text("Focus order"))
                                    .font(.system(.title2, design: .rounded, weight: .black))
                                    .foregroundStyle(JoyColors.ink)

                                Spacer()

                                Text(L10n.text("\(tips.count) AREAS"))
                                    .font(.system(.caption2, design: .rounded, weight: .bold))
                                    .tracking(L10n.isRightToLeft ? 0 : 0.8)
                                    .foregroundStyle(JoyColors.muted)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(JoyColors.surface.opacity(0.82), in: Capsule())
                                    .overlay(Capsule().stroke(JoyColors.ink.opacity(0.10), lineWidth: 1))
                            }
                            .padding(.top, 28)

                            VStack(spacing: 11) {
                                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                                    TipDetailCard(rank: index + 1, tip: tip)
                                }
                            }
                            .padding(.top, 14)
                            .analyticsSection("focus_order")

                            if let result = lastResult.result, result.faceShape != nil || result.undertone != nil {
                                styleSuggestionsHeader
                                    .padding(.top, 30)
                                    .analyticsSection("style_suggestions")

                                RecommendationGrid(faceShape: result.faceShape, undertone: result.undertone)
                                    .padding(.top, 14)
                            }

                            ScoresButton {
                                if let result = lastResult.result {
                                    router.presentReport(result)
                                } else {
                                    router.select(.home)
                                }
                            }
                            .padding(.top, 22)
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 132)
                    }
                    .analyticsScrollViewport("tips")
                }
            }
        }
        .environment(\.locale, L10n.locale)
        .analyticsScreen("tips")
    }

    private var tipsIntro: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(JoyColors.lemon)
                    .frame(width: 8, height: 8)

                Text(L10n.text("PERSONALIZED FOR YOU"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(L10n.isRightToLeft ? 0 : 1.4)
                    .foregroundStyle(JoyColors.muted)
            }

            Text(L10n.text("Tips for you"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(L10n.isRightToLeft ? 0 : -1.0)
                .foregroundStyle(JoyColors.ink)

            Text(summary)
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(JoyColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 18)
    }

    private var styleSuggestionsHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.text("Style suggestions"))
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(JoyColors.mint)
                    .frame(width: 7, height: 7)
                Text(L10n.text("MATCHED"))
            }
            .font(.system(.caption2, design: .rounded, weight: .bold))
            .tracking(L10n.isRightToLeft ? 0 : 0.8)
            .foregroundStyle(JoyColors.muted)
        }
    }

    private var summary: String {
        let high = tips.filter { $0.urgency == .high }
        let medium = tips.filter { $0.urgency == .medium }
        if high.isEmpty && medium.isEmpty {
            return NSLocalizedString("You're scoring well across the board. These cards are maintenance reminders for each category.", comment: "tips summary")
        }
        if let worst = high.first {
            return String(format: NSLocalizedString("Your weakest area is %1$@ (%2$@). Start at the top — actions are ranked from most to least leverage for your scan.", comment: "tips summary"),
                          worst.category.label, String(format: "%.1f", locale: L10n.locale, worst.score))
        }
        return L10n.text("Areas to refine: \(medium.count). Follow the order shown.")
    }
}

private struct RefinedTipsHeader: View {
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("LookGrade")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(JoyColors.mint)
                    .frame(width: 7, height: 7)
                Text(L10n.text("PERSONALIZED"))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(L10n.isRightToLeft ? 0 : 0.8)
                    .foregroundStyle(JoyColors.muted)
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
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(JoyColors.ink.opacity(0.07))
                .frame(height: 1)
        }
    }
}

private struct TipDetailCard: View {
    let rank: Int
    let tip: PersonalizedTip
    private var accent: Color { tipsAccent(for: tip.category) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                RankBadge(number: rank, accent: accent)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(tip.headline)
                            .font(.system(.headline, design: .rounded, weight: .black))
                            .foregroundStyle(JoyColors.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 4)

                        Pill(text: L10n.text("\(String(format: "%.1f", locale: L10n.locale, tip.score)) / 10"), color: accent)
                    }

                    HStack(spacing: 6) {
                        HStack(spacing: 5) {
                            LucideIcon(name: tip.icon, size: 13)
                            Text(tip.category.label.uppercased(with: L10n.locale))
                        }
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .tracking(L10n.isRightToLeft ? 0 : 0.5)
                        .foregroundStyle(JoyColors.muted)

                        UrgencyChip(urgency: tip.urgency)
                    }
                }
            }
            .padding(16)

            Text(tip.body)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(JoyColors.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 15)

            if !tip.actions.isEmpty {
                Rectangle()
                    .fill(JoyColors.ink.opacity(0.07))
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.text("DO THIS"))
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .tracking(L10n.isRightToLeft ? 0 : 1.1)
                        .foregroundStyle(JoyColors.ink.opacity(0.62))

                    ForEach(tip.actions, id: \.self) { action in
                        HStack(alignment: .top, spacing: 10) {
                            LucideIcon(name: "check", size: 11)
                                .foregroundStyle(JoyColors.ink)
                                .frame(width: 18, height: 18)
                                .background(accent.opacity(0.56), in: Circle())
                                .padding(.top, 1)

                            Text(action)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(JoyColors.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(16)
            }

            if !tip.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(tip.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .foregroundStyle(JoyColors.muted)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(JoyColors.canvas.opacity(0.72), in: Capsule())
                            .overlay(Capsule().stroke(JoyColors.ink.opacity(0.09), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(JoyColors.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(JoyColors.ink.opacity(tip.urgency == .high ? 0.16 : 0.11), lineWidth: 1)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent.opacity(0.78))
                .frame(width: 4, height: tip.urgency == .high ? 48 : 30)
                .padding(.leading, 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private func tipsAccent(for category: ScoreCategory) -> Color {
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

private struct RankBadge: View {
    let number: Int
    let accent: Color
    var body: some View {
        Text(L10n.text("\(number)"))
            .font(.system(.subheadline, design: .rounded, weight: .black))
            .foregroundStyle(JoyColors.ink)
            .frame(width: 36, height: 36)
            .background(accent.opacity(0.52), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct Pill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .black))
            .foregroundStyle(JoyColors.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color.opacity(0.42), in: Capsule())
    }
}

private struct UrgencyChip: View {
    let urgency: TipUrgency
    private var config: (Color, String) {
        switch urgency {
        case .high: return (JoyColors.coralSoft, L10n.text("PRIORITY"))
        case .medium: return (JoyColors.lemon.opacity(0.52), L10n.text("IMPROVE"))
        case .maintain: return (JoyColors.mint.opacity(0.45), L10n.text("MAINTAIN"))
        }
    }
    var body: some View {
        Text(config.1)
            .font(.system(.caption2, design: .rounded, weight: .black))
            .tracking(L10n.isRightToLeft ? 0 : 0.5)
            .foregroundStyle(JoyColors.ink.opacity(0.76))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(config.0, in: Capsule())
    }
}

/// Personalized style suggestions derived from the heuristic face-shape and
/// undertone descriptors — turns the spec's "Coming soon" grid into something
/// that actually reacts to the scan.
private enum StyleAdvice {
    static func hair(_ shape: String?) -> String {
        switch shape {
        case "Round": return NSLocalizedString("Volume on top and length add balance.", comment: "hair advice")
        case "Square": return NSLocalizedString("Soft layers and side-swept styles ease strong angles.", comment: "hair advice")
        case "Heart": return NSLocalizedString("Chin-length styles balance a wider forehead.", comment: "hair advice")
        case "Oblong": return NSLocalizedString("A fringe and side width shorten a long face.", comment: "hair advice")
        default: return NSLocalizedString("Most styles suit an oval shape — experiment freely.", comment: "hair advice")
        }
    }
    static func glasses(_ shape: String?) -> String {
        switch shape {
        case "Round": return NSLocalizedString("Angular, rectangular frames add definition.", comment: "glasses advice")
        case "Square": return NSLocalizedString("Round or oval frames soften the jaw.", comment: "glasses advice")
        case "Heart": return NSLocalizedString("Bottom-heavy or rimless frames balance the brow.", comment: "glasses advice")
        case "Oblong": return NSLocalizedString("Tall, bold frames break up the length.", comment: "glasses advice")
        default: return NSLocalizedString("Oval faces carry almost any frame well.", comment: "glasses advice")
        }
    }
    static func skincare(_ undertone: String?) -> String {
        switch undertone {
        case "Warm": return NSLocalizedString("Vitamin C and gold-toned SPF flatter warm skin.", comment: "skincare advice")
        case "Cool": return NSLocalizedString("Niacinamide and a neutral SPF suit cool skin.", comment: "skincare advice")
        default: return NSLocalizedString("A gentle SPF plus hydration fits any undertone.", comment: "skincare advice")
        }
    }
    static func makeup(_ undertone: String?) -> String {
        switch undertone {
        case "Warm": return NSLocalizedString("Gold, peach, and warm browns pop on you.", comment: "makeup advice")
        case "Cool": return NSLocalizedString("Silver, rose, and berry tones complement you.", comment: "makeup advice")
        default: return NSLocalizedString("Both warm and cool palettes work — pick by mood.", comment: "makeup advice")
        }
    }
}

private struct RecommendationGrid: View {
    let faceShape: String?
    let undertone: String?

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
            RecommendationCard(icon: "sparkles", title: L10n.text("Hair styles"), advice: StyleAdvice.hair(faceShape), accent: JoyColors.lemon)
            RecommendationCard(icon: "eye", title: L10n.text("Glasses"), advice: StyleAdvice.glasses(faceShape), accent: JoyColors.sky)
            RecommendationCard(icon: "droplet", title: L10n.text("Skincare"), advice: StyleAdvice.skincare(undertone), accent: JoyColors.mint)
            RecommendationCard(icon: "smile", title: L10n.text("Makeup"), advice: StyleAdvice.makeup(undertone), accent: JoyColors.coral)
        }
    }
}

private struct RecommendationCard: View {
    let icon: String
    let title: String
    let advice: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 36, height: 36)
                .background(accent.opacity(0.50), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            Text(title)
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)

            Text(advice)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(JoyColors.muted)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 146, alignment: .topLeading)
        .padding(15)
        .background(JoyColors.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.11), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct ScoresButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 11) {
                LucideIcon(name: "chart-line", size: 18)
                    .frame(width: 36, height: 36)
                    .background(JoyColors.sky.opacity(0.48), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("See your scores"))
                        .font(.system(.headline, design: .rounded, weight: .black))
                    Text(L10n.text("Open your full face report"))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(JoyColors.muted)
                }

                Spacer()

                LucideIcon(name: "arrow-right", size: 19)
            }
            .foregroundStyle(JoyColors.ink)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .frame(minHeight: 66)
            .background(JoyColors.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(JoyColors.ink.opacity(0.14), lineWidth: 1.1)
            )
        }
        .buttonStyle(TipsPressStyle())
        .accessibilityHint(L10n.text("Opens your latest score report"))
    }
}

private struct EmptyTipsView: View {
    var onScan: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle().fill(JoyColors.surface)

                LucideIcon(name: "sparkles", size: 40)
                    .foregroundStyle(JoyColors.ink)

                Circle()
                    .fill(JoyColors.lemon)
                    .frame(width: 16, height: 16)
                    .offset(x: 31, y: -31)
            }
            .frame(width: 96, height: 96)
            .overlay(Circle().stroke(JoyColors.ink.opacity(0.14), lineWidth: 1.2))

            Text(L10n.text("No tips yet"))
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)

            Text(L10n.text("Run a scan to get tips tailored to your weakest categories."))
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(JoyColors.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)

            Spacer()

            Button {
                Haptics.medium()
                onScan()
            } label: {
                HStack(spacing: 9) {
                    LucideIcon(name: "scan-face", size: 21)
                    Text(L10n.text("Run a scan"))
                        .font(.system(.headline, design: .rounded, weight: .black))
                    Spacer()
                    LucideIcon(name: "arrow-right", size: 19)
                }
                .foregroundStyle(JoyColors.ink)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background(JoyColors.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(JoyColors.ink.opacity(0.30), lineWidth: 1.2)
                )
            }
            .buttonStyle(TipsPressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 116)
    }
}

private struct QuietTipsBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(JoyColors.lemon.opacity(0.08))
                .frame(width: 190, height: 190)
                .position(x: geometry.size.width + 50, y: 130)

            Circle()
                .fill(JoyColors.mint.opacity(0.06))
                .frame(width: 180, height: 180)
                .position(x: -45, y: geometry.size.height * 0.72)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct TipsPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}
