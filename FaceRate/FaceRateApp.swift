import SwiftUI
import RevenueCat

@main
struct FaceRateApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var appPrefs: AppPrefsModel
    @State private var scanHistory: ScanHistoryModel
    @State private var entitlements: EntitlementsModel
    @State private var lastResult: LastResultModel
    private let router: AppRouter
    private let scanCoordinator: ScanCoordinator

    init() {
        // Order matters: migrate legacy Flutter-written UserDefaults data
        // and configure RevenueCat BEFORE any store/model reads its state.
        LegacyDataMigrator.runOnce()

        #if DEBUG
        // One-shot QA hook used when a previously installed development build
        // needs to exercise the true first-launch flow again. This resets only
        // the onboarding flag; scan history and the rest of the app data stay.
        if ProcessInfo.processInfo.environment["FACERATE_RESET_ONBOARDING"] == "1" {
            AppPrefsStore().reset()
        }
        if ProcessInfo.processInfo.environment["FACERATE_RESET_EXIT_OFFER"] == "1" {
            UserDefaults.standard.removeObject(forKey: PaywallExitOffer.consumedKey)
        }
        #endif

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
        AppAnalytics.shared.configure(revenueCatID: Purchases.shared.appUserID)

        let prefsModel = AppPrefsModel()
        let entitlementsModel = EntitlementsModel()
        let historyModel = ScanHistoryModel()
        let resultModel = LastResultModel()
        // Seed the last-result from history on first launch after upgrade so
        // Home/Tips show real scores immediately, not an empty card.
        resultModel.hydrateIfNeeded(from: historyModel.entries.first)

        #if DEBUG
        if ProcessInfo.processInfo.environment["PREVIEW_SCREEN"] != nil {
            // Screen previews are interactive QA builds, not screenshots.
            // Give them local test access so every scan entry point exercises
            // the real capture flow without a RevenueCat purchase.
            entitlementsModel.grantTestAccess()
            historyModel.clear()
            let now = Date()
            let seedCount = 5
            for i in 0..<seedCount {
                // Append oldest-first so the newest scan lands at entries[0]
                // (the store inserts each new entry at the front), and let the
                // score rise over time to show an improving trend.
                let daysAgo = (seedCount - 1 - i) * 3
                let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
                historyModel.append(ScanResult(
                    input: ScanInput(imagePath: "", capturedAt: date, source: .mock),
                    overallScore: 7.6 + Double(i) * 0.15,
                    potentialDelta: 0.5,
                    categories: MockScanData.categoryScores,
                    findings: MockScanData.findings
                ))
            }
        }
        #endif

        _appPrefs = State(initialValue: prefsModel)
        _entitlements = State(initialValue: entitlementsModel)
        _scanHistory = State(initialValue: historyModel)
        _lastResult = State(initialValue: resultModel)
        router = AppRouter(entitlements: entitlementsModel, history: historyModel)
        scanCoordinator = ScanCoordinator(
            analysisService: VisionAnalysisService(),
            lastResult: resultModel,
            history: historyModel
        )
    }

    var body: some Scene {
        WindowGroup {
            content
                .environment(appPrefs)
                .environment(scanHistory)
                .environment(entitlements)
                .environment(lastResult)
                .environment(router)
                .environment(scanCoordinator)
                // Follow the user’s system or per-app language and region.
                .environment(\.locale, L10n.locale)
                .environment(\.layoutDirection, L10n.isRightToLeft ? .rightToLeft : .leftToRight)
                // FaceRate now has one calm, consistent dark appearance.
                // This also keeps system sheets, permissions, and RevenueCat
                // presentation in the same visual environment.
                .preferredColorScheme(.dark)
                .onAppear { AppAnalytics.shared.lifecycle(scenePhase) }
                .onChange(of: scenePhase) { _, phase in AppAnalytics.shared.lifecycle(phase) }
                .task(id: Bundle.main.preferredLocalizations.first) {
                    // iOS restarts the app after its preferred language changes.
                    // Refresh existing reminder copy without asking permission again.
                    if appPrefs.remindersEnabled {
                        await ReminderManager.scheduleWeekly()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if let screen = ProcessInfo.processInfo.environment["PREVIEW_SCREEN"] {
            DebugScreenPreview(screen: screen)
        } else {
            RootView()
        }
        #else
        RootView()
        #endif
    }
}

#if DEBUG
/// DEBUG-only QA aid — jump straight to a named screen via the
/// `PREVIEW_SCREEN` env var (set through `SIMCTL_CHILD_PREVIEW_SCREEN` when
/// launching in the simulator) so each screen can be screenshotted without
/// manual navigation. Compiled out of Release builds via `#if DEBUG`.
private struct DebugScreenPreview: View {
    let screen: String

    var body: some View {
        switch screen {
        case "onboarding": OnboardingScreen(onFinish: {})
        case "consent": ConsentScreen(onContinue: {})
        // Keep the real app chrome around Home so simulator previews also
        // exercise every tab and the central scan action.
        case "home": DebugTabShell(initialTab: .home)
        case "capture": CaptureScreen(onCancel: {}, onCaptured: { _ in })
        case "first-scan-ready": FirstScanReadyPreview()
        case "first-scan-intro": FirstScanFlowView(onCancel: {}, onUnlock: { _ in })
        case "report": ScoreReportScreen(result: MockScanData.seedResult(), onSeeTips: {}, onSettings: {})
        case "tips": DebugTabShell(initialTab: .tips)
        case "progress": DebugTabShell(initialTab: .progress)
        case "profile": DebugTabShell(initialTab: .profile)
        case "paywall": PaywallScreen()
        default: RootView()
        }
    }
}

private struct DebugTabShell: View {
    @Environment(AppRouter.self) private var router
    let initialTab: AppTab
    @State private var didSetInitialTab = false

    var body: some View {
        TabShellView()
            .onAppear {
                guard !didSetInitialTab else { return }
                didSetInitialTab = true
                router.select(initialTab)
            }
    }
}
#endif
