import SwiftUI

/// The 4 real destinations behind the shell (matches `app_shell.dart`'s
/// route-prefix tab derivation — DESIGN.md §3.7's prose only lists 3 side
/// tabs but the actual navigation has 4; Tips sits to the right of the
/// raised Scan FAB alongside Profile).
enum AppTab: CaseIterable {
    case home, progress, tips, profile

    var icon: String {
        switch self {
        case .home: return "house"
        case .progress: return "chart-line"
        case .tips: return "lightbulb"
        case .profile: return "circle-user"
        }
    }

    var label: String {
        switch self {
        case .home: return NSLocalizedString("Home", comment: "tab")
        case .progress: return NSLocalizedString("Progress", comment: "tab")
        case .tips: return NSLocalizedString("Tips", comment: "tab")
        case .profile: return NSLocalizedString("Profile", comment: "tab")
        }
    }
}

/// DESIGN.md §3.7 — a fixed-height tab row whose solid glass background
/// extends under the home indicator via the bottom safe-area inset (so the
/// bar reads as ~84pt on notch devices and collapses cleanly on devices with
/// no bottom inset, instead of hardcoding 84 and floating the row). A raised
/// center Scan FAB overflows the top edge by 18 with a hairline top edge.
struct BottomNav: View {
    let selected: AppTab
    let onSelectTab: (AppTab) -> Void
    let onScan: () -> Void

    private var usesJoyStyle: Bool { selected == .home || selected == .progress || selected == .tips || selected == .profile }

    var body: some View {
        HStack(spacing: 0) {
            tabButton(.home)
            tabButton(.progress)
            Spacer().frame(width: 68) // room for the raised FAB
            tabButton(.tips)
            tabButton(.profile)
        }
        .padding(.horizontal, AppSpacing.sm12)
        .frame(maxWidth: .infinity)
        // Bar is anchored to the physical bottom (TabShellView ignores the
        // bottom safe area). We give the tab row a fixed top gap and just
        // enough bottom clearance for the home indicator — rather than
        // consuming the whole safe-area inset, which on large-inset devices
        // left a tall empty band under the labels.
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(usesJoyStyle ? JoyColors.surface : AppColors.bgSurface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(usesJoyStyle ? JoyColors.ink.opacity(0.18) : AppColors.borderSubtle)
                .frame(height: 1)
        }
        // The raised FAB is an overlay so it doesn't reserve layout height —
        // otherwise its 62pt bounds inflate the bar and leave dead space below
        // the tab labels. It floats above the row, overflowing the top edge.
        .overlay(alignment: .top) {
            scanButton.offset(y: -18)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = tab == selected
        return Button {
            Haptics.selection()
            onSelectTab(tab)
        } label: {
            VStack(spacing: 5) {
                LucideIcon(name: tab.icon, size: 23)
                Text(tab.label)
                    .appFont(.overline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity)
            }
            // Inactive uses textSecondary (not textTertiary) so the 11pt label
            // clears the 4.5:1 contrast bar for small text.
            .foregroundStyle(tabColor(isActive: isActive))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
        }
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private var scanButton: some View {
        Button {
            Haptics.medium()
            onScan()
        } label: {
            LucideIcon(name: "scan-face", size: 27)
                .foregroundStyle(Color.white)
                .frame(width: 62, height: 62)
                .background {
                    if usesJoyStyle {
                        Circle()
                            .fill(JoyColors.coral)
                            .shadow(color: JoyColors.ink.opacity(0.07), radius: 0, y: 3)
                    } else {
                        Circle()
                            .fill(AppColors.accentGradient)
                            .shadow(color: AppColors.accentGlow.opacity(0.3), radius: 10, y: 3)
                    }
                }
                .overlay(
                    Circle().strokeBorder(
                        usesJoyStyle ? JoyColors.ink : Color.white.opacity(0.12),
                        lineWidth: usesJoyStyle ? 2 : 1
                    )
                )
        }
        .accessibilityLabel(L10n.text("Start a new scan"))
    }

    private func tabColor(isActive: Bool) -> Color {
        if usesJoyStyle {
            return isActive ? JoyColors.coral : JoyColors.muted
        }
        return isActive ? AppColors.accentPrimary : AppColors.textSecondary
    }
}

#Preview {
    VStack {
        Spacer()
        BottomNav(selected: .home, onSelectTab: { _ in }, onScan: {})
    }
    .background(AppColors.bgPrimary)
    .ignoresSafeArea()
}
