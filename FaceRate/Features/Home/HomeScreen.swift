import SwiftUI

/// A calmer expression of the playful FaceRate palette. Navigation and data
/// contracts stay unchanged; Home owns presentation only.
struct HomeScreen: View {
    @Environment(LastResultModel.self) private var lastResult
    @Environment(ScanHistoryModel.self) private var history
    @Environment(AppRouter.self) private var router

    private var hasRealScan: Bool { !history.entries.isEmpty }

    private var dateLabel: String {
        guard let first = history.entries.first else { return L10n.text("No scans yet") }
        return first.capturedAt.formatted(
            .dateTime
                .locale(L10n.locale)
                .month(.abbreviated)
                .day()
                .hour()
                .minute()
        )
    }

    var body: some View {
        ZStack {
            JoyColors.canvas.ignoresSafeArea()
            QuietHomeBackdrop()

            VStack(spacing: 0) {
                RefinedHomeHeader(
                    streak: history.currentStreak(),
                    onSettings: { router.select(.profile) }
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        heroCopy

                        if hasRealScan, let result = lastResult.result {
                            RefinedScoreCard(
                                result: result,
                                delta: scanDelta,
                                dateLabel: dateLabel,
                                onOpenReport: { router.presentReport(result) },
                                onOpenCategory: { router.showProgress(category: $0) }
                            )
                            .padding(.top, 24)
                        } else {
                            RefinedScoreTeaser()
                                .padding(.top, 24)
                        }

                        RefinedScanButton(hasPreviousScan: hasRealScan) {
                            router.startScanFlow(source: "home_new_scan")
                        }
                        .padding(.top, 16)

                        RefinedTrustBar()
                            .padding(.top, 12)

                        if hasRealScan, !opportunities.isEmpty {
                            opportunitySection
                                .padding(.top, 32)
                                .analyticsSection("next_moves")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 132)
                }
                .analyticsScrollViewport("home")
            }
        }
        .analyticsScreen("home")
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(JoyColors.coral)
                    .frame(width: 8, height: 8)

                Text(L10n.text("TODAY'S FACE CHECK"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(L10n.isRightToLeft ? 0 : 1.4)
                    .foregroundStyle(JoyColors.muted)
            }

            Text(L10n.text("What's your face\nscore today?"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(L10n.isRightToLeft ? 0 : -1.0)
                .foregroundStyle(JoyColors.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.text("One quick scan reveals the details hiding in plain sight."))
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(JoyColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 22)
    }

    private var opportunitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.text("Your next moves"))
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)

                Spacer()

                Button {
                    Haptics.selection()
                    router.select(.tips)
                } label: {
                    HStack(spacing: 5) {
                        Text(L10n.text("View all"))
                        LucideIcon(name: "arrow-right", size: 14)
                    }
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(JoyColors.coral)
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                ForEach(Array(opportunities.enumerated()), id: \.offset) { index, item in
                    RefinedOpportunityRow(
                        number: index + 1,
                        title: item.headline,
                        bodyText: item.body,
                        icon: item.icon,
                        tint: index.isMultiple(of: 2) ? JoyColors.sky : JoyColors.mint
                    )
                }
            }
        }
    }

    /// The two lowest-scoring categories, ascending — unchanged product logic.
    private var opportunities: [PersonalizedTip] {
        let sorted = (lastResult.result?.categories ?? []).sorted { $0.value < $1.value }
        return sorted.prefix(2).map { TipBuilder.forScore($0.category, $0.value) }
    }

    /// Change in overall score versus the previous scan, if one exists.
    private var scanDelta: Double? {
        guard history.entries.count >= 2 else { return nil }
        return history.entries[0].overallScore - history.entries[1].overallScore
    }
}

private struct RefinedHomeHeader: View {
    let streak: Int
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("LookGrade")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)

            Spacer()

            HStack(spacing: 5) {
                Text("🔥")
                    .font(.system(size: 13))
                Text(L10n.text("\(streak)"))
                    .font(.system(.caption, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(JoyColors.surface.opacity(0.88), in: Capsule())
            .overlay(Capsule().stroke(JoyColors.ink.opacity(0.13), lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(streak == 0 ? L10n.text("No active streak") : L10n.text("Current streak: \(L10n.duration(streak, unit: .day))"))

            Button {
                Haptics.selection()
                onSettings()
            } label: {
                LucideIcon(name: "settings", size: 19)
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

private struct RefinedScoreTeaser: View {
    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.text("Your score is waiting"))
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)

                Text(L10n.text("Skin • Balance • Symmetry"))
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(JoyColors.muted)

                Label(L10n.text("1 photo • about 30 sec"), systemImage: "photo")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(JoyColors.muted)
            }

            Spacer(minLength: 0)

            Text("?")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(JoyColors.ink)
                .frame(width: 74, height: 74)
                .background(JoyColors.lemon.opacity(0.88), in: Circle())
        }
        .padding(20)
        .background(JoyColors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.16), lineWidth: 1.2)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct RefinedScoreCard: View {
    let result: ScanResult
    let delta: Double?
    let dateLabel: String
    let onOpenReport: () -> Void
    let onOpenCategory: (ScoreCategory) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button {
                Haptics.selection()
                onOpenReport()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(JoyColors.coral)
                                .frame(width: 4, height: 15)
                            Text(L10n.text("LATEST SCORE"))
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .tracking(L10n.isRightToLeft ? 0 : 1.1)
                                .foregroundStyle(JoyColors.muted)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(String(format: "%.1f", locale: L10n.locale, result.overallScore))
                                .font(.system(size: 56, weight: .black, design: .rounded))
                            Text("/10")
                                .font(.system(.headline, design: .rounded, weight: .black))
                        }
                        .foregroundStyle(JoyColors.ink)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 9) {
                        Text(dateLabel)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(JoyColors.muted)

                        if let delta {
                            RefinedDeltaPill(delta: delta)
                        }

                        HStack(spacing: 5) {
                            Text(L10n.text("Full report"))
                            LucideIcon(name: "arrow-right", size: 13)
                        }
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundStyle(JoyColors.coral)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .padding(20)
            }
            .buttonStyle(RefinedPressStyle())
            .accessibilityHint(L10n.text("Opens your full score report"))

            Rectangle()
                .fill(JoyColors.ink.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 20)

            HStack(spacing: 8) {
                scoreShortcut(label: L10n.text("Skin"), category: .skin, tint: JoyColors.mint)
                scoreShortcut(label: L10n.text("Balance"), category: .harmony, tint: JoyColors.lemon)
                scoreShortcut(label: L10n.text("Symmetry"), category: .symmetry, tint: JoyColors.sky)
            }
            .padding(14)
        }
        .background(JoyColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.17), lineWidth: 1.2)
        )
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(JoyColors.surface)
                .shadow(color: JoyColors.ink.opacity(0.045), radius: 0, y: 2)
        }
    }

    private func scoreShortcut(label: String, category: ScoreCategory, tint: Color) -> some View {
        Button {
            Haptics.selection()
            onOpenCategory(category)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                    Spacer(minLength: 2)
                    LucideIcon(name: "arrow-right", size: 11)
                }
                .foregroundStyle(JoyColors.muted)

                Text(String(format: "%.1f", locale: L10n.locale, result.score(for: category)))
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(tint.opacity(0.38), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(RefinedPressStyle())
        .accessibilityHint(L10n.text("Opens this analysis in Progress"))
    }
}

private struct RefinedDeltaPill: View {
    let delta: Double

    var body: some View {
        let positive = delta >= 0
        HStack(spacing: 4) {
            LucideIcon(name: "trending-up", size: 12)
                .rotationEffect(positive ? .zero : .degrees(180))
            Text("\(positive ? "+" : "")\(String(format: "%.1f", locale: L10n.locale, delta))")
        }
        .font(.system(.caption, design: .rounded, weight: .black))
        .foregroundStyle(JoyColors.ink)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background((positive ? JoyColors.mint : JoyColors.coralSoft).opacity(0.58), in: Capsule())
    }
}

private struct RefinedScanButton: View {
    let hasPreviousScan: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 11) {
                LucideIcon(name: "scan-face", size: 20)
                    .foregroundStyle(JoyColors.ink)
                    .frame(width: 36, height: 36)
                    .background(JoyColors.surface.opacity(0.80), in: Circle())

                Text(hasPreviousScan ? L10n.text("Scan again") : L10n.text("Reveal my score"))
                    .font(.system(.headline, design: .rounded, weight: .black))

                Spacer()

                LucideIcon(name: "arrow-right", size: 19)
            }
            .foregroundStyle(JoyColors.ink)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(JoyColors.coral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(JoyColors.ink.opacity(0.30), lineWidth: 1.2)
            )
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(JoyColors.coral)
                    .shadow(color: JoyColors.ink.opacity(0.05), radius: 0, y: 2)
            }
        }
        .buttonStyle(RefinedPressStyle())
        .accessibilityHint(L10n.text("Starts the face scan flow"))
    }
}

private struct RefinedTrustBar: View {
    var body: some View {
        HStack(spacing: 0) {
            RefinedTrustItem(icon: "smartphone", title: L10n.text("On-device"))
            divider
            RefinedTrustItem(icon: "history", title: L10n.text("30 sec"))
            divider
            RefinedTrustItem(icon: "shield", title: L10n.text("No uploads"))
        }
        .padding(.vertical, 10)
        .background(JoyColors.surface.opacity(0.70), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.10), lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(JoyColors.ink.opacity(0.09))
            .frame(width: 1, height: 20)
    }
}

private struct RefinedTrustItem: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            LucideIcon(name: icon, size: 13)
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
        }
        .foregroundStyle(JoyColors.muted)
        .frame(maxWidth: .infinity)
    }
}

private struct RefinedOpportunityRow: View {
    let number: Int
    let title: String
    let bodyText: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", locale: L10n.locale, number))
                .font(.system(.caption, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.muted)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .bold))
                    .foregroundStyle(JoyColors.ink)

                Text(bodyText)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(JoyColors.muted)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            LucideIcon(name: icon, size: 18)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.48), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(15)
        .background(JoyColors.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.11), lineWidth: 1)
        )
    }
}

private struct QuietHomeBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(JoyColors.sky.opacity(0.10))
                .frame(width: 190, height: 190)
                .position(x: geometry.size.width + 50, y: 120)

            Circle()
                .fill(JoyColors.lemon.opacity(0.06))
                .frame(width: 180, height: 180)
                .position(x: -45, y: geometry.size.height * 0.70)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct RefinedPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}
