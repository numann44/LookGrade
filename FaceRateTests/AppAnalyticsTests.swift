import XCTest
@testable import FaceRate

@MainActor
final class AppAnalyticsTests: XCTestCase {
    func testSectionsMustActuallyIntersectViewport() {
        let viewport = CGRect(x: 0, y: 0, width: 390, height: 700)
        XCTAssertFalse(AnalyticsVisibility.isVisible(CGRect(x: 0, y: 701, width: 390, height: 300), in: viewport))
        XCTAssertFalse(AnalyticsVisibility.isVisible(CGRect(x: 0, y: 680, width: 390, height: 300), in: viewport))
        XCTAssertTrue(AnalyticsVisibility.isVisible(CGRect(x: 0, y: 650, width: 390, height: 300), in: viewport))
        XCTAssertFalse(AnalyticsVisibility.isVisible(.zero, in: viewport))
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "analytics-tests-\(UUID().uuidString)")!
    }

    func testUnknownAndDeniedConsentSendNothing() {
        var events: [String] = []
        let analytics = AppAnalytics(defaults: makeDefaults()) { event, _ in events.append(event) }
        analytics.track(.paywallViewed)
        analytics.setConsent(false)
        analytics.track(.purchaseStarted)
        XCTAssertTrue(events.isEmpty)
    }

    func testOptInAndWithdrawalDoNotReplayEarlierEvents() {
        var events: [String] = []
        let analytics = AppAnalytics(defaults: makeDefaults()) { event, _ in events.append(event) }
        analytics.track(.onboardingAction)
        analytics.setConsent(true)
        analytics.track(.paywallClose)
        analytics.setConsent(false)
        analytics.track(.purchaseStarted)
        XCTAssertEqual(events, ["App Opened", "Paywall Close Tapped"])
    }

    func testConsentSurvivesNewInstance() {
        let defaults = makeDefaults()
        AppAnalytics(defaults: defaults).setConsent(false)
        XCTAssertEqual(AppAnalytics(defaults: defaults).consent, .denied)
    }

    func testSensitiveFieldsAndInvalidValuesAreRejected() {
        let output = AnalyticsPayload.sanitized([
            "name": "private", "photo": Data([1]), "overall_score": 7.1,
            "imagePath": "/private/photo.jpg", "error_message": "private data",
            "confidence": 0.7, "face_shape": "private", "email": "private",
            "action": "continue", "step_index": 3, "price": 74.99,
            "duration_seconds": Double.infinity, "state": ["secret": "nested"],
            "source": String(repeating: "x", count: 161)
        ])
        XCTAssertEqual(Set(output.keys), ["action", "step_index", "price"])
    }

    func testPurchaseAndOfferContextSurvivesSanitization() {
        let input: [String: Any] = ["product_id": "facerate_yearly_exit", "currency": "USD",
            "price": 37.49, "variant": "private_offer", "trial_eligible": true,
            "paywall_visit_id": "test-visit", "available_product_ids": ["facerate_yearly", "facerate_monthly"]]
        XCTAssertEqual(AnalyticsPayload.sanitized(input).count, input.count)
    }

    func testLifecycleDoesNotDuplicateActiveEvent() {
        var events: [String] = []
        let analytics = AppAnalytics(defaults: makeDefaults()) { event, _ in events.append(event) }
        analytics.setConsent(true)
        events.removeAll()
        analytics.lifecycle(.active)
        analytics.lifecycle(.active)
        analytics.lifecycle(.inactive)
        analytics.lifecycle(.active)
        analytics.lifecycle(.background)
        analytics.lifecycle(.background)
        XCTAssertEqual(events, ["App Opened", "App Backgrounded"])
    }
}
