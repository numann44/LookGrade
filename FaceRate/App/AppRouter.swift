import Foundation
import Observation

/// Navigation state for the app. `startScanFlow()` is the single entitlement
/// gate — every "start a scan" entry point calls this one method rather than
/// duplicating the canScan branch (mirrors `scan_gate.dart`).
@Observable
@MainActor
final class AppRouter {
    var selectedTab: AppTab = .home
    /// Selected analysis when Progress is opened from one of Home's score
    /// shortcuts. Kept in the router so the selection survives tab changes.
    var progressCategory: ScoreCategory?
    var showScanFlow = false
    var showPaywall = false
    var paywallSource = "profile"
    var showScanLimitAlert = false
    private(set) var nextScanAvailability: Date?
    /// A past result the user re-opened (from Home / Progress / Tips). Drives a
    /// modally-presented Score Report so the report isn't a one-time dead-end.
    var presentedReport: ReportPresentation?

    private let entitlements: EntitlementsModel
    private let history: ScanHistoryModel

    init(entitlements: EntitlementsModel, history: ScanHistoryModel) {
        self.entitlements = entitlements
        self.history = history
    }

    func startScanFlow(source: String = "screen_action") {
        let origin = source == "screen_action" ? String(describing: selectedTab) : source
        AppAnalytics.shared.track(.scanRequested, ["source": origin])
        guard entitlements.canScan else {
            AppAnalytics.shared.track(.scanBlocked, ["reason": "subscription_required", "source": origin])
            paywallSource = origin
            showPaywall = true
            return
        }

        let quota = history.quotaStatus()
        guard quota.canAnalyze else {
            AppAnalytics.shared.track(.scanBlocked, ["reason": "daily_limit", "source": origin])
            nextScanAvailability = quota.nextReset
            showScanLimitAlert = true
            return
        }

        nextScanAvailability = nil
        showScanFlow = true
    }

    var scanLimitMessage: String {
        let prefix = L10n.text("Your plan includes 5 face analyses every 24 hours.")
        guard let nextScanAvailability else { return prefix }

        let minutes = max(1, Int(ceil(nextScanAvailability.timeIntervalSinceNow / 60)))
        let hoursPart = minutes / 60
        let minutesPart = minutes % 60
        let wait: String
        if hoursPart > 0 && minutesPart > 0 {
            wait = [L10n.duration(hoursPart, unit: .hour), L10n.duration(minutesPart, unit: .minute)].joined(separator: " ")
        } else if hoursPart > 0 {
            wait = L10n.duration(hoursPart, unit: .hour)
        } else {
            wait = L10n.duration(minutesPart, unit: .minute)
        }
        return L10n.text("\(prefix) Your next analysis becomes available in \(wait).")
    }

    func select(_ tab: AppTab, source: String = "screen_action") {
        AppAnalytics.shared.track(.navigation, ["source": source, "destination": String(describing: tab)])
        selectedTab = tab
    }

    func showProgress(category: ScoreCategory? = nil) {
        AppAnalytics.shared.track(.navigation, ["action": "category_shortcut", "destination": "progress", "section": category?.rawValue ?? "overall"])
        progressCategory = category
        selectedTab = .progress
    }

    func presentReport(_ result: ScanResult) {
        AppAnalytics.shared.track(.reportAction, ["action": "open_report", "source": String(describing: selectedTab)])
        presentedReport = ReportPresentation(result: result)
    }
}

/// Identifiable wrapper so a re-opened Score Report can be driven by
/// `.fullScreenCover(item:)`.
struct ReportPresentation: Identifiable {
    let id = UUID()
    let result: ScanResult
}
