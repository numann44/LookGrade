import SwiftUI
import UIKit

/// Side-by-side before/after comparison of two scans, with photo thumbnails
/// (when available) and per-category deltas. Presented from Progress.
struct CompareView: View {
    let entries: [ScanHistoryEntry] // newest-first
    var onClose: () -> Void

    @State private var beforeIndex: Int
    @State private var afterIndex: Int

    init(entries: [ScanHistoryEntry], onClose: @escaping () -> Void) {
        self.entries = entries
        self.onClose = onClose
        _beforeIndex = State(initialValue: max(0, entries.count - 1)) // oldest
        _afterIndex = State(initialValue: 0)                          // newest
    }

    private var before: ScanHistoryEntry { entries[min(beforeIndex, entries.count - 1)] }
    private var after: ScanHistoryEntry { entries[min(afterIndex, entries.count - 1)] }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(onClose: onClose)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.text("Before & after")).appFont(.h1).foregroundStyle(AppColors.textPrimary)
                        Text(L10n.text("Compare any two scans to see what's changed."))
                            .appFont(.body).foregroundStyle(AppColors.textSecondary)
                    }

                    HStack(alignment: .top, spacing: AppSpacing.sm12) {
                        sideCard(label: L10n.text("BEFORE"), entry: before, index: $beforeIndex)
                        sideCard(label: L10n.text("AFTER"), entry: after, index: $afterIndex)
                    }

                    overallDeltaCard

                    VStack(alignment: .leading, spacing: AppSpacing.sm12) {
                        Text(L10n.text("By category")).appFont(.h2).foregroundStyle(AppColors.textPrimary)
                        VStack(spacing: AppSpacing.xs8) {
                            ForEach(ScoreCategory.allCases, id: \.self) { cat in
                                DeltaRow(category: cat, delta: value(after, cat) - value(before, cat))
                            }
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md16)
                .padding(.top, AppSpacing.md16)
                .padding(.bottom, 100)
            }
        }
        .background(AppColors.bgPrimary.ignoresSafeArea())
        .analyticsScreen("compare")
        .onChange(of: beforeIndex) { _, _ in AppAnalytics.shared.track(.reportAction, ["action": "compare_before_changed"]) }
        .onChange(of: afterIndex) { _, _ in AppAnalytics.shared.track(.reportAction, ["action": "compare_after_changed"]) }
    }

    private func value(_ entry: ScanHistoryEntry, _ category: ScoreCategory) -> Double {
        entry.categories[category.rawValue] ?? 0
    }

    private var overallDeltaCard: some View {
        let delta = after.overallScore - before.overallScore
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text("OVERALL CHANGE")).appFont(.overline).foregroundStyle(AppColors.textSecondary)
                Text(String(format: L10n.text("%.1f → %.1f"), locale: L10n.locale, before.overallScore, after.overallScore))
                    .appFont(.h2, tabularNumbers: true).foregroundStyle(AppColors.textPrimary)
            }
            Spacer()
            DeltaBadge(delta: delta, large: true)
        }
        .padding(AppSpacing.lg20)
        .glassCard(cornerRadius: AppRadius.xl)
    }

    private func sideCard(label: String, entry: ScanHistoryEntry, index: Binding<Int>) -> some View {
        VStack(spacing: AppSpacing.xs8) {
            Text(LocalizedStringKey(label)).appFont(.overline).foregroundStyle(AppColors.textSecondary)

            Group {
                if let image = ScanPhotoLibrary.image(for: entry.id) {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        AppColors.bgSurfaceElevated
                        LucideIcon(name: "image-off", size: 28).foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))

            Text(String(format: "%.1f", locale: L10n.locale, entry.overallScore))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
            Text(entry.capturedAt.formatted(
                .dateTime
                    .locale(L10n.locale)
                    .month(.abbreviated)
                    .day()
                    .year()
            ))
                .appFont(.caption).foregroundStyle(AppColors.textSecondary)

            HStack(spacing: AppSpacing.md16) {
                stepButton("chevron-left", disabled: index.wrappedValue >= entries.count - 1) {
                    index.wrappedValue = min(entries.count - 1, index.wrappedValue + 1) // older
                }
                stepButton("chevron-right", disabled: index.wrappedValue <= 0) {
                    index.wrappedValue = max(0, index.wrappedValue - 1) // newer
                }
            }
        }
        .padding(AppSpacing.sm12)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: AppRadius.lg, shadow: false)
    }

    private func stepButton(_ icon: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(disabled ? AppColors.textTertiary : AppColors.accentPrimary)
                .frame(width: 40, height: 32)
                .background(AppColors.bgSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        }
        .disabled(disabled)
        .accessibilityLabel(icon == "chevron-left" ? L10n.text("Older scan") : L10n.text("Newer scan"))
    }
}

private struct DeltaRow: View {
    let category: ScoreCategory
    let delta: Double
    var body: some View {
        HStack {
            Circle().fill(AppColors.score(for: category)).frame(width: 8, height: 8)
            Text(category.label).appFont(.body).foregroundStyle(AppColors.textPrimary)
            Spacer()
            DeltaBadge(delta: delta, large: false)
        }
        .padding(.horizontal, AppSpacing.md16).padding(.vertical, AppSpacing.sm12)
        .glassCard(shadow: false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.text("\(category.label) change \(String(format: "%.1f", locale: L10n.locale, delta))"))
    }
}

private struct DeltaBadge: View {
    let delta: Double
    let large: Bool
    private var positive: Bool { delta >= 0.05 }
    private var negative: Bool { delta <= -0.05 }
    private var color: Color {
        if positive { return AppColors.stateSuccess }
        if negative { return AppColors.stateDanger }
        return AppColors.textSecondary
    }
    var body: some View {
        HStack(spacing: 4) {
            if positive || negative {
                LucideIcon(name: "trending-up", size: large ? 16 : 12)
                    .rotationEffect(positive ? .zero : .degrees(180))
            }
            Text(delta.magnitude < 0.05 ? "—" : "\(positive ? "+" : "")\(String(format: "%.1f", locale: L10n.locale, delta))")
                .appFont(large ? .bodyStrong : .caption, tabularNumbers: true)
        }
        .foregroundStyle(color)
        .padding(.horizontal, large ? AppSpacing.sm12 : 8)
        .padding(.vertical, large ? 8 : 4)
        .background(color.opacity(0.14))
        .clipShape(Capsule())
    }
}
