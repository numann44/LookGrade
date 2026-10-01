import SwiftUI
import Charts

struct ProgressScreen: View {
    @Environment(ScanHistoryModel.self) private var history
    @Environment(AppRouter.self) private var router
    @State private var showCompare = false

    var body: some View {
        @Bindable var router = router

        ZStack {
            JoyColors.canvas.ignoresSafeArea()
            QuietProgressBackdrop()

            VStack(spacing: 0) {
                JoyfulProgressHeader(onSettings: { router.select(.profile) })

                if history.entries.isEmpty {
                    EmptyProgressView { router.startScanFlow() }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            progressIntro

                            CategorySelector(selected: $router.progressCategory)
                                .padding(.top, 22)

                            StatsHeader(entries: history.entries, category: router.progressCategory)
                                .padding(.top, 18)

                            TrendChart(entries: history.entries, category: router.progressCategory)
                                .padding(.top, 14)
                                .analyticsSection("trend_chart")

                            if history.entries.count >= 2 {
                                CompareButton { showCompare = true }
                                    .padding(.top, 16)
                            }

                            historySection
                                .padding(.top, 30)
                                .analyticsSection("history")
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 132)
                    }
                    .analyticsScrollViewport("progress")
                }
            }
        }
        .environment(\.locale, L10n.locale)
        .analyticsScreen("progress")
        .onChange(of: router.progressCategory) { _, category in
            AppAnalytics.shared.track(.navigation, ["action": "progress_filter", "section": category?.rawValue ?? "overall"])
        }
        .onChange(of: showCompare) { _, shown in
            AppAnalytics.shared.track(.navigation, ["action": shown ? "compare_open" : "compare_close"])
        }
        .fullScreenCover(isPresented: $showCompare) {
            CompareView(entries: history.entries) { showCompare = false }
        }
    }

    private var progressIntro: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(JoyColors.sky)
                    .frame(width: 8, height: 8)

                Text(L10n.text("YOUR JOURNEY"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(L10n.isRightToLeft ? 0 : 1.4)
                    .foregroundStyle(JoyColors.muted)
            }

            Text(L10n.text("Progress"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(L10n.isRightToLeft ? 0 : -1.0)
                .foregroundStyle(JoyColors.ink)

            Text(L10n.text("Trends across your scans."))
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(JoyColors.muted)
        }
        .padding(.top, 18)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.text("History"))
                    .font(.system(.title2, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)

                Spacer()

                Text(L10n.text("\(history.entries.count) SCANS"))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(L10n.isRightToLeft ? 0 : 0.8)
                    .foregroundStyle(JoyColors.muted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(JoyColors.surface.opacity(0.82), in: Capsule())
                    .overlay(Capsule().stroke(JoyColors.ink.opacity(0.10), lineWidth: 1))
            }

            VStack(spacing: 10) {
                ForEach(Array(history.entries.enumerated()), id: \.element.id) { index, entry in
                    let previous = index + 1 < history.entries.count ? history.entries[index + 1] : nil
                    Button {
                        router.presentReport(.reconstruct(from: entry))
                    } label: {
                        HistoryRow(
                            entry: entry,
                            delta: previous.map { entry.overallScore - $0.overallScore },
                            accent: historyAccent(at: index)
                        )
                    }
                    .buttonStyle(ProgressPressStyle())
                    .accessibilityHint(L10n.text("Opens this scan's report"))
                }
            }
        }
    }

    private func historyAccent(at index: Int) -> Color {
        let colors = [JoyColors.coral, JoyColors.sky, JoyColors.mint, JoyColors.lemon]
        return colors[index % colors.count]
    }
}

private func value(_ entry: ScanHistoryEntry, _ category: ScoreCategory?) -> Double {
    guard let category else { return entry.overallScore }
    return entry.categories[category.rawValue] ?? 0
}

private func progressAccent(for category: ScoreCategory?) -> Color {
    switch category {
    case nil: return JoyColors.coral
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

private struct JoyfulProgressHeader: View {
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
                Text(L10n.text("TRACKING"))
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

private struct CategorySelector: View {
    @Binding var selected: ScoreCategory?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: L10n.text("Overall"), category: nil)
                ForEach(ScoreCategory.allCases, id: \.self) { category in
                    chip(label: category.label, category: category)
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    private func chip(label: String, category: ScoreCategory?) -> some View {
        let isSelected = category == selected
        let accent = progressAccent(for: category)

        return Button {
            Haptics.selection()
            selected = category
        } label: {
            Text(label)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(isSelected ? JoyColors.ink : JoyColors.muted)
                .padding(.horizontal, 15)
                .frame(minHeight: 44)
                .background(isSelected ? accent.opacity(0.72) : JoyColors.surface.opacity(0.82), in: Capsule())
                .overlay(
                    Capsule().stroke(
                        isSelected ? JoyColors.ink.opacity(0.28) : JoyColors.ink.opacity(0.11),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(ProgressPressStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct StatsHeader: View {
    let entries: [ScanHistoryEntry]
    let category: ScoreCategory?

    var body: some View {
        let values = entries.map { value($0, category) }
        let latest = values.first ?? 0
        let earliest = values.last ?? 0
        let delta = latest - earliest
        let accent = progressAccent(for: category)

        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(accent)
                        .frame(width: 4, height: 15)

                    Text(category?.label.uppercased(with: L10n.locale) ?? L10n.text("OVERALL SCORE"))
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .tracking(L10n.isRightToLeft ? 0 : 1.0)
                        .foregroundStyle(JoyColors.muted)
                }

                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(String(format: "%.1f", locale: L10n.locale, latest))
                        .font(.system(size: 48, weight: .black, design: .rounded))
                    Text("/10")
                        .font(.system(.headline, design: .rounded, weight: .black))
                }
                .foregroundStyle(JoyColors.ink)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                DeltaPill(delta: delta)
                    .fixedSize()
                Text(L10n.text("FROM FIRST SCAN"))
                    .font(.system(.caption2, design: .rounded, weight: .black))
                    .tracking(L10n.isRightToLeft ? 0 : 0.7)
                    .foregroundStyle(JoyColors.ink.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(JoyColors.surface)
                .shadow(color: JoyColors.ink.opacity(0.045), radius: 0, y: 2)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.17), lineWidth: 1.2)
        )
    }
}

private struct DeltaPill: View {
    let delta: Double
    private var positive: Bool { delta >= 0 }

    var body: some View {
        HStack(spacing: 5) {
            LucideIcon(name: "trending-up", size: 14)
                .rotationEffect(positive ? .zero : .degrees(180))
            Text(L10n.text("\(positive ? "+" : "")\(String(format: "%.1f", locale: L10n.locale, delta))"))
                .font(.system(.subheadline, design: .rounded, weight: .black))
        }
        .foregroundStyle(JoyColors.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((positive ? JoyColors.mint : JoyColors.coralSoft).opacity(0.55), in: Capsule())
    }
}

private struct TrendChart: View {
    let entries: [ScanHistoryEntry]
    let category: ScoreCategory?

    var body: some View {
        let chronological = Array(entries.reversed())
        let accent = progressAccent(for: category)
        let latest = chronological.last

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.text("SCORE CURVE"))
                        .font(.system(.caption, design: .rounded, weight: .black))
                        .tracking(L10n.isRightToLeft ? 0 : 1.1)
                        .foregroundStyle(JoyColors.ink)
                    Text(L10n.text("Every scan, in one view"))
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(JoyColors.muted)
                }

                Spacer()

                Circle()
                    .fill(accent.opacity(0.80))
                    .frame(width: 11, height: 11)
            }

            Chart {
                ForEach(Array(chronological.enumerated()), id: \.offset) { _, entry in
                    LineMark(
                        x: .value(L10n.text("Date"), entry.capturedAt),
                        y: .value(L10n.text("Score"), value(entry, category))
                    )
                    .foregroundStyle(accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value(L10n.text("Date"), entry.capturedAt),
                        y: .value(L10n.text("Score"), value(entry, category))
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accent.opacity(0.24), accent.opacity(0.01)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }

                if let latest {
                    PointMark(
                        x: .value(L10n.text("Date"), latest.capturedAt),
                        y: .value(L10n.text("Score"), value(latest, category))
                    )
                    .foregroundStyle(accent)
                    .symbolSize(105)
                    .annotation(position: .top, spacing: 5) {
                        Text(String(format: "%.1f", locale: L10n.locale, value(latest, category)))
                            .font(.system(.caption, design: .rounded, weight: .black))
                            .foregroundStyle(JoyColors.ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(accent.opacity(0.48), in: Capsule())
                    }
                }
            }
            .chartYScale(domain: 0...10)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10]) {
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .foregroundStyle(JoyColors.ink.opacity(0.10))
                    AxisValueLabel()
                        .foregroundStyle(JoyColors.muted)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { axisValue in
                    AxisGridLine()
                        .foregroundStyle(JoyColors.ink.opacity(0.08))
                    AxisValueLabel {
                        if let date = axisValue.as(Date.self) {
                            Text(date.formatted(
                                .dateTime
                                    .locale(L10n.locale)
                                    .month(.twoDigits)
                                    .day(.twoDigits)
                            ))
                            .foregroundStyle(JoyColors.muted)
                        }
                    }
                }
            }
            .frame(height: 210)
        }
        .padding(18)
        .background(JoyColors.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.15), lineWidth: 1.2)
        )
    }
}

private struct CompareButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 10) {
                LucideIcon(name: "scale", size: 18)
                    .frame(width: 36, height: 36)
                    .background(JoyColors.lemon.opacity(0.48), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text(L10n.text("Compare before & after"))
                    .font(.system(.headline, design: .rounded, weight: .bold))

                Spacer()

                LucideIcon(name: "arrow-right", size: 19)
            }
            .foregroundStyle(JoyColors.ink)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .frame(minHeight: 62)
            .background(JoyColors.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(JoyColors.ink.opacity(0.14), lineWidth: 1.1)
            )
        }
        .buttonStyle(ProgressPressStyle())
    }
}

private struct HistoryRow: View {
    let entry: ScanHistoryEntry
    let delta: Double?
    let accent: Color

    var body: some View {
        HStack(spacing: 13) {
            Text(String(format: "%.1f", locale: L10n.locale, entry.overallScore))
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)
                .frame(width: 50, height: 50)
                .background(accent.opacity(0.40), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.capturedAt.formatted(
                    .dateTime
                        .locale(L10n.locale)
                        .month(.abbreviated)
                        .day()
                        .hour()
                        .minute()
                ))
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)

                Text(L10n.text("Potential +\(String(format: "%.1f", locale: L10n.locale, entry.potentialDelta))"))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(JoyColors.muted)
            }

            Spacer(minLength: 4)

            if let delta {
                DeltaPill(delta: delta)
            } else {
                LucideIcon(name: "arrow-right", size: 17)
                    .foregroundStyle(JoyColors.muted)
            }
        }
        .padding(13)
        .background(JoyColors.surface.opacity(0.88), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.11), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct EmptyProgressView: View {
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle().fill(JoyColors.surface)
                LucideIcon(name: "chart-line", size: 42)
                    .foregroundStyle(JoyColors.ink)

                Circle()
                    .fill(JoyColors.lemon)
                    .frame(width: 16, height: 16)
                    .offset(x: 31, y: -31)
            }
            .frame(width: 96, height: 96)
            .overlay(Circle().stroke(JoyColors.ink.opacity(0.14), lineWidth: 1.2))

            Text(L10n.text("No progress yet"))
                .font(.system(.title, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)

            Text(L10n.text("Run your first scan to see how your scores trend over time."))
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
            .buttonStyle(ProgressPressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 116)
    }
}

private struct QuietProgressBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(JoyColors.mint.opacity(0.09))
                .frame(width: 190, height: 190)
                .position(x: geometry.size.width + 50, y: 130)

            Circle()
                .fill(JoyColors.sky.opacity(0.06))
                .frame(width: 180, height: 180)
                .position(x: -45, y: geometry.size.height * 0.72)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct ProgressPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}
