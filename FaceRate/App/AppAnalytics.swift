import Foundation
import Observation
import SwiftUI
import Mixpanel

/// Explicit, consent-gated product analytics. Never pass user-entered text,
/// photos, scores, face measurements, file paths, or raw error messages here.
enum AnalyticsConfig {
    // Public ingestion token, not a service-account/admin secret.
    // LookGrade / 4065703 — EU project, Europe/Istanbul reporting timezone.
    static let projectToken = "8517fda4808651d5cf8a61a46a59c613"
    static let serverURL = "https://api-eu.mixpanel.com"
}

enum AnalyticsEvent: String, CaseIterable {
    case appOpened = "App Opened", appBackgrounded = "App Backgrounded"
    case screenViewed = "Screen Viewed", screenLeft = "Screen Left", sectionViewed = "Section Viewed"
    case onboardingAction = "Onboarding Action", onboardingCompleted = "Onboarding Completed"
    case consentAction = "Privacy Agreement Action"
    case scanRequested = "Scan Requested", scanBlocked = "Scan Blocked"
    case cameraAction = "Camera Action", cameraState = "Camera State Changed"
    case analysisStarted = "Analysis Started", analysisCompleted = "Analysis Completed"
    case analysisFailed = "Analysis Failed", analysisCancelled = "Analysis Cancelled"
    case reportAction = "Report Action", navigation = "Navigation Action"
    case paywallViewed = "Paywall Viewed", plansLoaded = "Paywall Plans Loaded"
    case plansFailed = "Paywall Plans Failed", planSelected = "Paywall Plan Selected"
    case paywallClose = "Paywall Close Tapped", offerIntro = "Private Offer Intro Viewed"
    case offerViewed = "Private Offer Viewed", offerUnavailable = "Private Offer Unavailable"
    case offerWarning = "Private Offer Leave Warning", offerKept = "Private Offer Kept"
    case paywallLeft = "Paywall Left", purchaseStarted = "Purchase Started"
    case purchaseCompleted = "Purchase Completed", purchaseCancelled = "Purchase Cancelled"
    case purchaseFailed = "Purchase Failed", restoreStarted = "Restore Started"
    case restoreCompleted = "Restore Completed", restoreFailed = "Restore Failed"
    case settingsAction = "Settings Action"
}

/// A small allowlist protects against accidentally forwarding arbitrary model
/// dictionaries or NSError.userInfo to the analytics provider.
enum AnalyticsPayload {
    static let allowedKeys: Set<String> = [
        "screen", "previous_screen", "action", "source", "destination", "step", "step_index",
        "section", "selected", "selection_count", "has_name", "reason", "state", "duration_seconds",
        "product_id", "package_id", "offering_id", "price", "currency", "trial_eligible",
        "variant", "paywall_visit_id", "available_product_ids", "product_count", "has_access",
        "is_locked", "mode", "error_code", "permission", "result", "is_sandbox", "period_type"
    ]

    static func sanitized(_ input: [String: Any]) -> [String: Any] {
        input.filter { key, value in
            guard allowedKeys.contains(key) else { return false }
            if let string = value as? String { return string.count <= 160 }
            if let strings = value as? [String] { return strings.count <= 12 && strings.allSatisfy { $0.count <= 160 } }
            if value is Bool || value is Int { return true }
            if let number = value as? Double { return number.isFinite }
            return false
        }
    }
}

@Observable @MainActor
final class AppAnalytics {
    static let shared = AppAnalytics()
    static let consentKey = "lookgrade.analytics.consent.v1"
    enum Consent: String { case unknown, allowed, denied }
    private(set) var consent: Consent
    private let defaults: UserDefaults
    @ObservationIgnored private var sdk: MixpanelInstance?
    @ObservationIgnored private var sink: ((String, [String: Any]) -> Void)?
    @ObservationIgnored private var sessionID = UUID().uuidString
    @ObservationIgnored private var backgroundAt: Date?
    @ObservationIgnored private var currentScreen: String?
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var identity: String?
    @ObservationIgnored private var isActive = false
    @ObservationIgnored private var sequence = 0

    // Injecting a sink keeps unit tests completely offline.
    init(defaults: UserDefaults = .standard, sink: ((String, [String: Any]) -> Void)? = nil) {
        self.defaults = defaults
        self.sink = sink
        consent = Consent(rawValue: defaults.string(forKey: Self.consentKey) ?? "") ?? .unknown
    }

    func configure(revenueCatID: String) {
        identity = revenueCatID
        guard !configured else { return }
        configured = true
        #if DEBUG
        // Normal debug/previews/tests never contaminate production analytics.
        guard ProcessInfo.processInfo.environment["LOOKGRADE_ANALYTICS_QA"] == "1" else { return }
        #endif
        guard !AnalyticsConfig.projectToken.isEmpty else { return }
        sdk = Mixpanel.initialize(options: MixpanelOptions(
            token: AnalyticsConfig.projectToken, flushInterval: 15,
            trackAutomaticEvents: false, optOutTrackingByDefault: true,
            useUniqueDistinctId: false, serverURL: AnalyticsConfig.serverURL,
            featureFlagsEnabled: false
        ))
        sdk?.useIPAddressForGeoLocation = false
        if consent == .allowed { enableSDK() }
    }

    func setConsent(_ allowed: Bool) {
        consent = allowed ? .allowed : .denied
        defaults.set(consent.rawValue, forKey: Self.consentKey)
        if allowed {
            enableSDK()
            track(.appOpened, ["source": "analytics_opt_in"])
        } else {
            // SDK clears queued events and resets its local identity on opt-out.
            sdk?.optOutTracking()
        }
    }

    private func enableSDK() {
        sdk?.optInTracking()
        if let identity { sdk?.identify(distinctId: identity, usePeople: false) }
    }

    func track(_ event: AnalyticsEvent, _ properties: [String: Any] = [:]) {
        guard consent == .allowed else { return }
        var payload = AnalyticsPayload.sanitized(properties)
        sequence += 1
        payload["schema_version"] = 1
        payload["session_id"] = sessionID
        payload["event_sequence"] = sequence
        payload["screen"] = payload["screen"] ?? currentScreen ?? "unknown"
        payload["app_version"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        payload["app_build"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        payload["app_language"] = Bundle.main.preferredLocalizations.first ?? "en"
        #if DEBUG
        payload["environment"] = "development"
        #else
        payload["environment"] = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? "sandbox" : "production"
        #endif
        sink?(event.rawValue, payload)
        let mixpanelProperties: Properties = payload.reduce(into: [:]) { result, pair in
            if let value = pair.value as? MixpanelType { result[pair.key] = value }
        }
        sdk?.track(event: event.rawValue, properties: mixpanelProperties)
    }

    func screenViewed(_ name: String) {
        let previous = currentScreen
        currentScreen = name
        var properties: [String: Any] = ["screen": name]
        if let previous { properties["previous_screen"] = previous }
        track(.screenViewed, properties)
    }

    func lifecycle(_ phase: ScenePhase) {
        if phase == .active {
            guard !isActive else { return }
            isActive = true
            if let backgroundAt, Date().timeIntervalSince(backgroundAt) >= 1_800 {
                sessionID = UUID().uuidString
                sequence = 0
            }
            track(.appOpened, ["source": backgroundAt == nil ? "launch" : "foreground"])
            backgroundAt = nil
        } else if phase == .background {
            guard isActive else { return }
            isActive = false
            backgroundAt = Date()
            track(.appBackgrounded)
            sdk?.flush()
        }
    }

    func flush() { sdk?.flush() }

    /// The support team can locate and delete opted-in events using this ID.
    /// It is copied only at the user's explicit request, never emailed silently.
    var privacySupportID: String? { identity }
}

/// Measures visible foreground time, not time spent in another app. A visit
/// ends on navigation/background; returning produces a separate screen visit.
private struct AnalyticsScreenModifier: ViewModifier {
    let name: String
    @Environment(\.scenePhase) private var phase
    @State private var started: Date?
    @State private var visible = false
    func body(content: Content) -> some View {
        content
            .onAppear { visible = true; start() }
            .onDisappear { end("navigation"); visible = false }
            .onChange(of: name) { old, _ in end("navigation", name: old); start() }
            .onChange(of: phase) { _, value in
                if value == .active && visible { start() }
                else if value == .background { end("background") }
            }
    }
    private func start() {
        guard started == nil else { return }
        started = Date()
        AppAnalytics.shared.screenViewed(name)
    }
    private func end(_ reason: String, name oldName: String? = nil) {
        guard let began = started else { return }
        AppAnalytics.shared.track(.screenLeft, ["screen": oldName ?? name, "reason": reason,
                                               "duration_seconds": max(0, Date().timeIntervalSince(began))])
        started = nil
    }
}

extension View {
    func analyticsScreen(_ name: String) -> some View { modifier(AnalyticsScreenModifier(name: name)) }

    /// Mark a section without collecting its text or underlying model values.
    func analyticsSection(_ section: String) -> some View {
        anchorPreference(key: AnalyticsSectionAnchors.self, value: .bounds) { [section: $0] }
    }

    func analyticsScrollViewport(_ screen: String) -> some View {
        modifier(AnalyticsViewportModifier(screen: screen))
    }
}

private struct AnalyticsSectionAnchors: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

enum AnalyticsVisibility {
    static func isVisible(_ frame: CGRect, in viewport: CGRect) -> Bool {
        let intersection = frame.intersection(viewport)
        return !intersection.isNull && intersection.width > 0 &&
            intersection.height >= min(40, frame.height) && frame.height > 0
    }
}

/// Anchor geometry is resolved against the actual ScrollView viewport, so
/// eager VStack construction does not report off-screen sections as seen.
private struct AnalyticsViewportModifier: ViewModifier {
    let screen: String
    @Environment(\.scenePhase) private var phase
    @State private var seen: Set<String> = []
    func body(content: Content) -> some View {
        content.overlayPreferenceValue(AnalyticsSectionAnchors.self) { anchors in
            GeometryReader { proxy in
                let visible = anchors.compactMap { key, anchor in
                    AnalyticsVisibility.isVisible(proxy[anchor], in: CGRect(origin: .zero, size: proxy.size)) ? key : nil
                }.sorted()
                Color.clear
                    .onChange(of: visible, initial: true) { _, values in record(values) }
                    .onChange(of: phase) { _, value in if value == .active { record(visible) } }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onDisappear { seen.removeAll() }
    }
    private func record(_ sections: [String]) {
        guard phase == .active, AppAnalytics.shared.consent == .allowed else { return }
        for section in sections where seen.insert(section).inserted {
            AppAnalytics.shared.track(.sectionViewed, ["screen": screen, "section": section])
        }
    }
}

/// Separate from the required face-analysis agreement: refusing analytics
/// must not change onboarding, purchases, or access to the app.
struct AnalyticsConsentScreen: View {
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            Spacer()
            Text("Help shape LookGrade")
                .font(.largeTitle.weight(.semibold))
            Text("May we collect optional usage analytics to improve your experience?")
                .font(.title3)
            Text("With your permission, Mixpanel receives screen visits, button actions, purchase outcomes, and basic app/device information under a pseudonymous ID. We never send your name, photos, face measurements, or scores. No advertising tracking or screen recordings.")
                .foregroundStyle(.secondary)
            Text("You can change this anytime in Settings. Either choice lets you continue.")
                .font(.footnote).foregroundStyle(.secondary)
            Link("Privacy Policy", destination: LegalLinks.privacy)
            Spacer()
            Button("Allow usage analytics") { AppAnalytics.shared.setConsent(true) }
                .buttonStyle(.borderedProminent).tint(AppColors.accentPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("analytics.allow")
            Button("Continue without analytics") { AppAnalytics.shared.setConsent(false) }
                .buttonStyle(.bordered).frame(maxWidth: .infinity)
                .accessibilityIdentifier("analytics.decline")
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppColors.bgPrimary.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
