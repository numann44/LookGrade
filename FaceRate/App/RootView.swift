import SwiftUI

/// Top-level switch. First-time users complete the tailored onboarding,
/// approve the privacy agreement, and take one locked preview scan before the
/// hard paywall. The preview does not consume the paid five-scan allowance.
struct RootView: View {
    private enum FirstLaunchStage {
        case onboarding
        case consent
        case firstScan
    }

    @Environment(AppPrefsModel.self) private var appPrefs
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementsModel.self) private var entitlementsModel
    @Environment(LastResultModel.self) private var lastResult
    @Environment(ScanCoordinator.self) private var scanCoordinator
    @AppStorage(PaywallExitOffer.consumedKey) private var hasConsumedExitOffer = false
    @State private var firstLaunchStage: FirstLaunchStage = .onboarding
    @State private var isRetryingOnboardingScan = false

    var body: some View {
        Group {
            if AppAnalytics.shared.consent == .unknown {
                AnalyticsConsentScreen()
            } else {
                appContent
            }
        }
    }

    private var appContent: some View {
        Group {
            if isRetryingOnboardingScan {
                FirstScanFlowView(
                    onCancel: {
                        withAnimation(.premiumEase) {
                            isRetryingOnboardingScan = false
                        }
                    },
                    onUnlock: handleOnboardingScanReady
                )
            } else if !appPrefs.hasSeenOnboarding {
                switch firstLaunchStage {
                case .onboarding:
                    OnboardingScreen {
                        withAnimation(.premiumEase) {
                            firstLaunchStage = .consent
                        }
                    }
                case .consent:
                    ConsentScreen(
                        onBack: {
                            withAnimation(.premiumEase) {
                                firstLaunchStage = .onboarding
                            }
                        },
                        onContinue: {
                            withAnimation(.premiumEase) {
                                firstLaunchStage = .firstScan
                            }
                        }
                    )
                case .firstScan:
                    FirstScanFlowView(
                        onCancel: {
                            withAnimation(.premiumEase) {
                                firstLaunchStage = .consent
                            }
                        },
                        onUnlock: handleOnboardingScanReady
                    )
                }
            } else if !entitlementsModel.hasAccess {
                // The first close reveals the one-time exit SKU. Declining it
                // returns to the onboarding scan, and later paywalls remain
                // fully dismissable but never recreate the exit discount.
                PaywallScreen(
                    dismissable: true,
                    allowsExitOffer: !hasConsumedExitOffer,
                    onExit: returnToOnboardingScan,
                    source: "onboarding_gate"
                )
            } else {
                TabShellView()
            }
        }
        .animation(.premiumEase, value: appPrefs.hasSeenOnboarding)
        .onChange(of: entitlementsModel.hasAccess) { _, hasAccess in
            guard hasAccess else { return }
            promotePendingOnboardingScanIfNeeded()
        }
        .onAppear(perform: promotePendingOnboardingScanIfNeeded)
    }

    /// A user may purchase immediately, restore later, or return after
    /// closing the paywall. In every case the original onboarding result is
    /// promoted exactly once into Home and Progress as soon as Pro is active.
    private func promotePendingOnboardingScanIfNeeded() {
        guard entitlementsModel.hasAccess,
              let expectedID = appPrefs.pendingOnboardingScanID,
              let result = lastResult.result,
              ScanHistoryEntry.id(forCapturedAt: result.input.capturedAt) == expectedID else {
            return
        }

        scanCoordinator.recordResultInHistory(result)
        appPrefs.clearPendingOnboardingScan()
        AppAnalytics.shared.track(.reportAction, ["action": "onboarding_result_saved", "source": "entitlement_unlocked"])
    }

    private func handleOnboardingScanReady(_ result: ScanResult) {
        AppAnalytics.shared.track(.reportAction, ["action": "unlock_tapped", "is_locked": true])
        appPrefs.markOnboardingScanPending(result)
        router.presentReport(result)
        if !appPrefs.hasSeenOnboarding {
            appPrefs.markOnboardingSeen()
        }
        isRetryingOnboardingScan = false
        promotePendingOnboardingScanIfNeeded()
    }

    private func returnToOnboardingScan() {
        // Persist immediately in the root source of truth so a transition
        // back into the scan flow can never recreate the exit SKU.
        hasConsumedExitOffer = true
        withAnimation(.premiumEase) {
            isRetryingOnboardingScan = true
            firstLaunchStage = .firstScan
        }
    }
}

/// The persistent bottom-tab chrome wrapping Home/Progress/Tips/Profile.
struct TabShellView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        ZStack {
            AppColors.bgPrimary.ignoresSafeArea()

            Group {
                switch router.selectedTab {
                case .home: HomeScreen()
                case .progress: ProgressScreen()
                case .tips: TipsScreen()
                case .profile: ProfileScreen()
                }
            }

            VStack {
                Spacer()
                BottomNav(
                    selected: router.selectedTab,
                    onSelectTab: { router.select($0, source: "bottom_tab") },
                    onScan: { router.startScanFlow(source: "bottom_tab") }
                )
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // Route-owned presentations live with the tab shell itself. This
        // keeps every entry point working in both the normal app and the
        // interactive DEBUG screen previews.
        .fullScreenCover(isPresented: Binding(
            get: { router.showScanFlow },
            set: { router.showScanFlow = $0 }
        )) {
            ScanFlowView()
        }
        .fullScreenCover(isPresented: Binding(
            get: { router.showPaywall },
            set: { router.showPaywall = $0 }
        )) {
            PaywallScreen(source: router.paywallSource)
        }
        .fullScreenCover(item: Binding(
            get: { router.presentedReport },
            set: { router.presentedReport = $0 }
        )) { presentation in
            ScoreReportScreen(
                result: presentation.result,
                onSeeTips: {
                    router.presentedReport = nil
                    router.select(.tips)
                },
                onSettings: {
                    router.presentedReport = nil
                    router.select(.profile)
                },
                onClose: { router.presentedReport = nil }
            )
        }
        .alert(L10n.text("Daily analysis limit reached"), isPresented: Binding(
            get: { router.showScanLimitAlert },
            set: { router.showScanLimitAlert = $0 }
        )) {
            Button(L10n.text("Got it"), role: .cancel) {}
        } message: {
            Text(router.scanLimitMessage)
        }
    }
}
