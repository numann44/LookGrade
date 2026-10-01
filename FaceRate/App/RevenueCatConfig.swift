import Foundation

/// RevenueCat project: "FaceRate" (proj8397f29e) — same project/key as the
/// Flutter app's revenuecat_config.dart, so existing sandbox purchases and
/// the RevenueCat project config carry over untouched; this is an SDK
/// swap, not a backend migration.
enum RevenueCatConfig {
    static let iosApiKey = "appl_eCboiAftXkCFYSEHlcksrYvMtYH"

    /// Debug builds use RevenueCat Test Store by default so the complete
    /// published paywall remains testable even while Apple has returned one or
    /// more IAPs with a rejected app version. Release builds always use the
    /// real App Store key. Set FACERATE_RC_APP_STORE=1 only when a Debug run
    /// specifically needs to audit Apple's live product catalog.
    #if DEBUG
    private static let testStoreApiKey = "test_BCiOHRlcXhxfrHiDuUEquIBlZsT"
    #endif

    static var apiKey: String {
        #if DEBUG
        if ProcessInfo.processInfo.environment["FACERATE_RC_APP_STORE"] != "1" {
            return testStoreApiKey
        }
        #endif
        return iosApiKey
    }

    /// Only App Store builds may attempt background subscription recovery.
    /// RevenueCat Test Store has no Apple receipt to restore.
    static var usesAppStore: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["FACERATE_RC_APP_STORE"] == "1"
        #else
        return true
        #endif
    }

    /// Identifier of the "FaceRate Pro" entitlement configured in RevenueCat.
    static let entitlementId = "pro"
}
