import SwiftUI
import UIKit

/// Account / settings screen. No login — everything is local and anonymous.
struct ProfileScreen: View {
    @Environment(EntitlementsModel.self) private var entitlementsModel
    @Environment(ScanHistoryModel.self) private var history
    @Environment(AppPrefsModel.self) private var appPrefs
    @Environment(LastResultModel.self) private var lastResult
    @Environment(AppRouter.self) private var router

    @State private var confirmClearHistory = false
    @State private var confirmDeleteAll = false
    @State private var showManageSheet = false

    private var ent: Entitlements { entitlementsModel.entitlements }

    var body: some View {
        ZStack {
            JoyColors.canvas.ignoresSafeArea()
            QuietProfileBackdrop()

            VStack(spacing: 0) {
                RefinedProfileHeader()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        profileIntro

                        PlanHeader(ent: ent)
                            .padding(.top, 20)

                        StatsRow(scans: history.entries.count, streak: history.currentStreak())
                            .padding(.top, 10)

                        if !ent.isPro && !entitlementsModel.hasAccess {
                            ProfileActionButton(
                                title: L10n.text("Upgrade to Pro"),
                                subtitle: L10n.text("Get 5 face analyses every 24 hours"),
                                icon: "sparkles",
                                filled: true
                            ) {
                                AppAnalytics.shared.track(.settingsAction, ["action": "upgrade"])
                                router.paywallSource = "profile_upgrade"
                                router.showPaywall = true
                            }
                            .padding(.top, 14)
                        } else if ent.isPro {
                            ProfileActionButton(
                                title: L10n.text("Manage subscription"),
                                subtitle: L10n.text("Plan and billing settings"),
                                icon: "settings",
                                filled: false
                            ) {
                                AppAnalytics.shared.track(.settingsAction, ["action": "manage_subscription"])
                                showManageSheet = true
                            }
                            .padding(.top, 14)
                        }

                        if entitlementsModel.hasAccess {
                            ProfileActionButton(
                                title: L10n.text("View plans"),
                                subtitle: L10n.text("Review plans and pricing anytime"),
                                icon: "sparkles",
                                filled: true
                            ) {
                                AppAnalytics.shared.track(.settingsAction, ["action": "view_plans"])
                                router.paywallSource = "profile_view_plans"
                                router.showPaywall = true
                            }
                            .padding(.top, 10)
                        }

                        SectionLabel(text: "PREFERENCES")
                            .padding(.top, 30)

                        ReminderToggle(enabled: appPrefs.remindersEnabled) { on in
                            await appPrefs.setReminders(on)
                            AppAnalytics.shared.track(.settingsAction, ["action": "reminders_toggle", "selected": appPrefs.remindersEnabled])
                            return appPrefs.remindersEnabled
                        }
                        .padding(.top, 10)

                        SettingsGroup {
                            Tile(
                                icon: "settings",
                                title: L10n.text("Language"),
                                subtitle: [
                                    L10n.locale.localizedString(forIdentifier: Bundle.main.preferredLocalizations.first ?? "en") ?? "English",
                                    L10n.text("Change in iOS Settings")
                                ].joined(separator: " · "),
                                trailingIcon: "chevron-right",
                                onTap: {
                                    AppAnalytics.shared.track(.settingsAction, ["action": "language_settings"])
                                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                                    UIApplication.shared.open(url)
                                }
                            )
                            .accessibilityIdentifier("settings.language")
                        }
                        .padding(.top, 10)

                        SectionLabel(text: "PRIVACY")
                            .padding(.top, 28)

                        SettingsGroup {
                            Tile(icon: "shield", title: L10n.text("On-device analysis"), subtitle: L10n.text("Your photos and scan analysis never leave the device. Vision runs locally."))
                            SettingsDivider()
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle("Usage analytics", isOn: Binding(
                                    get: { AppAnalytics.shared.consent == .allowed },
                                    set: { AppAnalytics.shared.setConsent($0) }
                                ))
                                .tint(JoyColors.mint)
                                Text("Optional screen and button analytics through Mixpanel. No names, photos, face measurements, scores, ad tracking, or screen recordings. Turning this off stops future collection; it does not erase previously sent events.")
                                    .font(.footnote).foregroundStyle(AppColors.textSecondary)
                                if let supportID = AppAnalytics.shared.privacySupportID {
                                    Button("Copy privacy request ID") {
                                        UIPasteboard.general.string = supportID
                                    }
                                    .font(.footnote)
                                    Text("Include this ID when contacting the Privacy Policy support address to request deletion of previously sent analytics.")
                                        .font(.caption).foregroundStyle(AppColors.textSecondary)
                                }
                            }
                            .padding(16)
                        }
                        .padding(.top, 10)

                        SectionLabel(text: "DATA")
                            .padding(.top, 28)

                        SettingsGroup {
                            Tile(
                                icon: "history",
                                title: L10n.text("Scan history"),
                                subtitle: L10n.text("Saved scans on this device: \(history.entries.count)"),
                                trailingLabel: history.entries.isEmpty ? nil : L10n.text("Clear"),
                                onTrailingTap: {
                                    AppAnalytics.shared.track(.settingsAction, ["action": "clear_history_requested"])
                                    confirmClearHistory = true
                                }
                            )
                            SettingsDivider()
                            Tile(
                                icon: "trash-2",
                                title: L10n.text("Delete all data"),
                                subtitle: L10n.text("Removes scan history and saved photos, and resets onboarding."),
                                trailingIcon: "chevron-right",
                                onTap: {
                                    AppAnalytics.shared.track(.settingsAction, ["action": "delete_local_data_requested"])
                                    confirmDeleteAll = true
                                }
                            )
                        }
                        .padding(.top, 10)

                        SectionLabel(text: "ABOUT")
                            .padding(.top, 28)

                        SettingsGroup {
                            Tile(icon: "info", title: L10n.text("How scoring works"), subtitle: L10n.text("Face landmarks + cheek pixel sampling, on device. A heuristic guide for self-tracking — not a medical, clinical, or attractiveness assessment."))
                            SettingsDivider()
                            Tile(icon: "info", title: L10n.text("Version"), subtitle: (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") + " (" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") + ")")
                        }
                        .padding(.top, 10)

                        SectionLabel(text: "LEGAL")
                            .padding(.top, 28)

                        SettingsGroup {
                            Tile(icon: "shield", title: L10n.text("Privacy policy"), subtitle: L10n.text("How your photos and data are handled."),
                                 trailingIcon: "chevron-right", onTap: { UIApplication.shared.open(LegalLinks.privacy) })
                            SettingsDivider()
                            Tile(icon: "info", title: L10n.text("Terms of use"), subtitle: L10n.text("Subscription terms and disclaimers."),
                                 trailingIcon: "chevron-right", onTap: { UIApplication.shared.open(LegalLinks.terms) })
                        }
                        .padding(.top, 10)
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 132)
                }
            }
        }
        .environment(\.locale, L10n.locale)
        .analyticsScreen("profile")
        .confirmationDialog(L10n.text("Clear scan history?"), isPresented: $confirmClearHistory, titleVisibility: .visible) {
            Button(L10n.text("Clear"), role: .destructive) {
                Haptics.medium()
                AppAnalytics.shared.track(.settingsAction, ["action": "clear_history_confirmed"])
                history.clear()
                ScanPhotoLibrary.clearAll()
            }
            Button(L10n.text("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("This deletes saved scan summaries. Your subscription and rolling 24-hour scan allowance stay as they are."))
        }
        .confirmationDialog(L10n.text("Delete all data?"), isPresented: $confirmDeleteAll, titleVisibility: .visible) {
            Button(L10n.text("Delete"), role: .destructive) {
                Haptics.heavy()
                // Do not reconnect analytics when local onboarding is reset.
                AppAnalytics.shared.setConsent(false)
                history.clear()
                entitlementsModel.preserveAccessAfterDataDeletion()
                appPrefs.reset()
                lastResult.reset()
                ScanImageStore.clearAll()
                ScanPhotoLibrary.clearAll()
                LegacyDataMigrator.clearLegacyData()
            }
            Button(L10n.text("Cancel"), role: .cancel) {}
        } message: {
            Text(L10n.text("Wipes photos, saved history, and onboarding. Your App Store subscription stays linked, and the 24-hour scan allowance is not reset. This cannot be undone."))
            Text("Usage analytics will be turned off. Previously sent analytics are not deleted by this local reset; contact the privacy support address to request their removal.")
        }
        .sheet(isPresented: $showManageSheet) {
            ManageSubscriptionSheet(ent: ent, managementURL: entitlementsModel.managementURL)
                .presentationDetents([.height(220)])
        }
    }

    private var profileIntro: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(JoyColors.mint)
                    .frame(width: 8, height: 8)

                Text(L10n.text("YOUR SPACE"))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .tracking(L10n.isRightToLeft ? 0 : 1.4)
                    .foregroundStyle(JoyColors.muted)
            }

            Text(L10n.text("Profile & settings"))
                .font(.system(size: 34, weight: .black, design: .rounded))
                .tracking(L10n.isRightToLeft ? 0 : -1.0)
                .foregroundStyle(JoyColors.ink)

            Text(L10n.text("Your plan, preferences, and private data — all in one place."))
                .font(.system(.body, design: .rounded, weight: .medium))
                .foregroundStyle(JoyColors.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 18)
    }
}

private struct RefinedProfileHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("LookGrade")
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(JoyColors.ink)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(JoyColors.sky)
                    .frame(width: 7, height: 7)
                Text(L10n.text("SETTINGS"))
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .tracking(L10n.isRightToLeft ? 0 : 0.8)
                    .foregroundStyle(JoyColors.muted)
            }

            LucideIcon(name: "settings", size: 20)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 38, height: 38)
                .background(JoyColors.surface.opacity(0.88), in: Circle())
                .overlay(Circle().stroke(JoyColors.ink.opacity(0.14), lineWidth: 1))
                .accessibilityHidden(true)
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

private struct ProfileActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.medium()
            action()
        } label: {
            HStack(spacing: 11) {
                LucideIcon(name: icon, size: 19)
                    .frame(width: 38, height: 38)
                    .background(
                        filled ? JoyColors.surface.opacity(0.78) : JoyColors.lemon.opacity(0.48),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .rounded, weight: .black))
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(filled ? JoyColors.ink.opacity(0.68) : JoyColors.muted)
                }

                Spacer()

                LucideIcon(name: "arrow-right", size: 19)
            }
            .foregroundStyle(JoyColors.ink)
            .padding(.horizontal, 15)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .frame(minHeight: 66)
            .background(
                filled ? JoyColors.coral : JoyColors.surface.opacity(0.88),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(JoyColors.ink.opacity(filled ? 0.30 : 0.14), lineWidth: 1.1)
            )
        }
        .buttonStyle(ProfilePressStyle())
    }
}

private struct PlanHeader: View {
    let ent: Entitlements
    private var accent: Color { ent.isPro ? JoyColors.mint : JoyColors.sky }

    var body: some View {
        HStack(spacing: 13) {
            LucideIcon(name: ent.isPro ? "sparkles" : "circle-user", size: 22)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 52, height: 52)
                .background(accent.opacity(0.52), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(ent.isPro ? "LookGrade Pro" : L10n.text("Free plan"))
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(JoyColors.ink)

                Text(planSubtitle)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(JoyColors.muted)
            }

            Spacer(minLength: 4)

            Text(ent.isPro ? "PRO" : L10n.text("LOCAL"))
                .font(.system(.caption2, design: .rounded, weight: .black))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .tracking(L10n.isRightToLeft ? 0 : 0.7)
                .foregroundStyle(JoyColors.ink.opacity(0.70))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(accent.opacity(0.38), in: Capsule())
        }
        .padding(17)
        .background(JoyColors.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.14), lineWidth: 1.1)
        )
        .accessibilityElement(children: .combine)
    }

    private var planSubtitle: String {
        if ent.isPro {
            let planName: String
            switch ent.plan {
            case .yearly: planName = L10n.text("Yearly")
            case .monthly: planName = L10n.text("Monthly")
            case .weekly: planName = L10n.text("Weekly")
            case nil: planName = L10n.text("Active")
            }
            return L10n.text("\(planName) subscription • 5 analyses / 24h")
        }
        return L10n.text("No active subscription")
    }
}

private struct StatsRow: View {
    let scans: Int
    let streak: Int
    var body: some View {
        HStack(spacing: 10) {
            StatBox(label: L10n.text("TOTAL SCANS"), value: "\(scans)", icon: "history", accent: JoyColors.sky)
            StatBox(label: L10n.text("CURRENT STREAK"), value: streak == 0 ? "0" : L10n.duration(streak, unit: .day), icon: "trending-up", accent: JoyColors.lemon)
        }
    }
}

private struct StatBox: View {
    let label: String
    let value: String
    let icon: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            LucideIcon(name: icon, size: 16)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 34, height: 34)
                .background(accent.opacity(0.46), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(.caption2, design: .rounded, weight: .black))
                    .tracking(L10n.isRightToLeft ? 0 : 0.6)
                    .foregroundStyle(JoyColors.muted)

                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(JoyColors.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.10), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct SectionLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(sectionAccent)
                .frame(width: 4, height: 14)

            Text(L10n.lookup(text))
                .font(.system(.caption, design: .rounded, weight: .black))
                .tracking(L10n.isRightToLeft ? 0 : 1.0)
                .foregroundStyle(JoyColors.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sectionAccent: Color {
        switch text {
        case "PREFERENCES": return JoyColors.lemon
        case "PRIVACY": return JoyColors.mint
        case "DATA": return JoyColors.sky
        case "ABOUT": return JoyColors.orange
        default: return JoyColors.coral
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(JoyColors.surface.opacity(0.90), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.11), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(JoyColors.ink.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 62)
    }
}

private struct Tile: View {
    let icon: String
    let title: String
    let subtitle: String
    var trailingIcon: String? = nil
    var trailingLabel: String? = nil
    var onTrailingTap: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil

    // A row wrapped in a `Button` disables everything inside it (including a
    // nested trailing button) when `onTap == nil`. So we only make the whole
    // row a button when it actually navigates; rows with just a trailing
    // action stay a plain container so that trailing control keeps working.
    var body: some View {
        Group {
            if let onTap {
                Button {
                    Haptics.selection()
                    onTap()
                } label: {
                    rowContent
                }
                .buttonStyle(ProfilePressStyle())
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 11) {
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 38, height: 38)
                .background(iconTint.opacity(0.46), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(JoyColors.ink)

                Text(subtitle)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(JoyColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let trailingLabel {
                Button {
                    Haptics.selection()
                    onTrailingTap?()
                } label: {
                    Text(trailingLabel)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(JoyColors.coral)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(JoyColors.coralSoft.opacity(0.72), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            if let trailingIcon {
                LucideIcon(name: trailingIcon, size: 18)
                    .foregroundStyle(JoyColors.muted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var iconTint: Color {
        switch icon {
        case "shield": return JoyColors.mint
        case "eye": return JoyColors.sky
        case "history": return JoyColors.lemon
        case "trash-2": return JoyColors.coralSoft
        default: return JoyColors.orange
        }
    }
}

private struct ReminderToggle: View {
    let enabled: Bool
    /// Returns the *actual* new state (may be false if permission was denied).
    var onToggle: (Bool) async -> Bool

    @State private var isOn: Bool
    @State private var busy = false

    init(enabled: Bool, onToggle: @escaping (Bool) async -> Bool) {
        self.enabled = enabled
        self.onToggle = onToggle
        _isOn = State(initialValue: enabled)
    }

    var body: some View {
        HStack(spacing: 11) {
            LucideIcon(name: "history", size: 18)
                .foregroundStyle(JoyColors.ink)
                .frame(width: 40, height: 40)
                .background(JoyColors.lemon.opacity(0.48), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.text("Weekly scan reminder"))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(JoyColors.ink)

                Text(L10n.text("A gentle nudge every Sunday to track your trend."))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(JoyColors.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Toggle("", isOn: Binding(
                get: { isOn },
                set: { newValue in
                    isOn = newValue
                    busy = true
                    Task { isOn = await onToggle(newValue); busy = false }
                }
            ))
            .labelsHidden()
            .tint(JoyColors.mint)
            .disabled(busy)
        }
        .padding(14)
        .background(JoyColors.surface.opacity(0.90), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(JoyColors.ink.opacity(0.11), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.text("Weekly scan reminder"))
        .accessibilityValue(isOn ? L10n.text("On") : L10n.text("Off"))
    }
}

private struct ManageSubscriptionSheet: View {
    let ent: Entitlements
    var managementURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Capsule()
                .fill(JoyColors.ink.opacity(0.14))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                LucideIcon(name: "settings", size: 18)
                    .foregroundStyle(JoyColors.ink)
                    .frame(width: 36, height: 36)
                    .background(JoyColors.lemon.opacity(0.48), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text(L10n.text("Manage subscription"))
                    .font(.system(.title3, design: .rounded, weight: .black))
                    .foregroundStyle(JoyColors.ink)
            }

            Text(planDescription)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(JoyColors.ink)

            Text(L10n.text("Includes 5 face analyses every 24 hours."))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(JoyColors.muted)

            Text(L10n.text("Cancelling or switching plans happens through the App Store."))
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(JoyColors.muted)

            Button {
                // RevenueCat's CustomerInfo.managementURL points straight at
                // this subscriber's App Store subscription management page;
                // falls back to the generic subscriptions page if unset.
                let destination = managementURL ?? URL(string: "https://apps.apple.com/account/subscriptions")
                if let destination {
                    UIApplication.shared.open(destination)
                }
            } label: {
                HStack(spacing: 8) {
                    Text(L10n.text("Open App Store settings"))
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                    Spacer()
                    LucideIcon(name: "arrow-right", size: 17)
                }
                .foregroundStyle(JoyColors.ink)
                .padding(.horizontal, 15)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(JoyColors.surface, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .stroke(JoyColors.ink.opacity(0.14), lineWidth: 1)
                )
            }
            .buttonStyle(ProfilePressStyle())
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(JoyColors.canvas.ignoresSafeArea())
    }

    private var planDescription: String {
        switch ent.plan {
        case .yearly: return L10n.text("You are on the Yearly plan.")
        case .monthly: return L10n.text("You are on the Monthly plan.")
        case .weekly: return L10n.text("You are on the Weekly plan.")
        case nil: return L10n.text("Your LookGrade Pro subscription is active.")
        }
    }
}

private struct QuietProfileBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            Circle()
                .fill(JoyColors.mint.opacity(0.08))
                .frame(width: 195, height: 195)
                .position(x: geometry.size.width + 50, y: 145)

            Circle()
                .fill(JoyColors.sky.opacity(0.05))
                .frame(width: 180, height: 180)
                .position(x: -45, y: geometry.size.height * 0.70)
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

private struct ProfilePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.11), value: configuration.isPressed)
    }
}
