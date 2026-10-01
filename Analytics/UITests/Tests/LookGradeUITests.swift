import XCTest

final class LookGradeUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.lokman.facerate")
    private var analyticsQA: String {
        ProcessInfo.processInfo.environment["LOOKGRADE_ANALYTICS_QA"] == "1" ? "1" : "0"
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        print("LOOKGRADE_SCREEN \(name)\n\(app.debugDescription)")
    }

    private func tap(_ label: String, timeout: TimeInterval = 10) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "Missing \(label)")
        XCTAssertTrue(button.isEnabled, "Disabled \(label)")
        button.tap()
    }

    private func completeDialogue() {
        for _ in 0..<12 {
            let dialogue = app.buttons["miro.dialogue.surface"]
            guard dialogue.waitForExistence(timeout: 1) else { return }
            dialogue.tap()
        }
        XCTAssertFalse(app.buttons["miro.dialogue.surface"].exists)
    }

    /// Run only against a fresh, dedicated iPhone 17 Pro simulator with the
    /// Debug Test Store build installed and the synthetic portrait first in Photos.
    /// No real App Store purchase is approved by this harness.
    func testFullReleaseJourney() {
        tryOnboardingAndCapture()
        tryPaywallPlanSelection()
        tryOfferExitRetryAndPurchase()
        tryNavigationAndRestore()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 20))
        app.swipeUp()
        verifyAnalyticsOptOutAndRelaunch()
    }

    /// Separate upgrade regression: an existing subscribed QA installation
    /// containing a saved scan is required. Not part of the clean-install script.
    func testExistingSubscriberPhotoAfterUpdate() {
        continueAfterFailure = false
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment = ["LOOKGRADE_ANALYTICS_QA": analyticsQA]
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 20))
        let score = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "LATEST SCORE")).firstMatch
        XCTAssertTrue(score.waitForExistence(timeout: 10))
        score.tap()
        XCTAssertTrue(app.images["Photo from this scan"].firstMatch.waitForExistence(timeout: 10))
        snapshot("29_photo_recovered_after_container_relocation")
        tap("Close")
        tap("Profile")
        app.swipeUp()
        XCTAssertEqual(app.switches["Usage analytics"].value as? String, "0")
        XCUIDevice.shared.press(.home)
    }

    private func tryOnboardingAndCapture() {
        continueAfterFailure = false
        addUIInterruptionMonitor(withDescription: "Photos permission") { alert in
            let allow = alert.buttons["Allow Full Access"]
            if allow.exists { allow.tap(); return true }
            return false
        }
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-lookgrade.analytics.consent.v1", "unknown"]
        app.launchEnvironment = ["LOOKGRADE_ANALYTICS_QA": analyticsQA, "FACERATE_RESET_ONBOARDING": "1", "FACERATE_RESET_EXIT_OFFER": "1"]
        app.launch()
        tap("analytics.decline")
        XCTAssertTrue(app.buttons["miro.dialogue.surface"].waitForExistence(timeout: 10))
        snapshot("01_decline_still_allows_onboarding")
        app.terminate()
        app.launch()
        tap("analytics.allow")
        completeDialogue()
        snapshot("02_baseline")
        tap("Continue")
        completeDialogue()
        let name = app.textFields.firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        name.tap()
        name.typeText("QA Tester")
        snapshot("03_name_keyboard")
        name.typeText("\n")
        snapshot("04_goals")
        tap("Find my score")
        tap("Look better")
        tap("Continue")
        let skin = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Texture & tone")).firstMatch
        XCTAssertTrue(skin.waitForExistence(timeout: 10))
        skin.tap()
        tap("Continue")
        XCTAssertTrue(app.sliders.firstMatch.waitForExistence(timeout: 10))
        app.sliders.firstMatch.adjust(toNormalizedSliderPosition: 0.8)
        tap("Continue")
        let ready = app.staticTexts["Your plan, QA Tester!"]
        XCTAssertTrue(ready.waitForExistence(timeout: 20))
        snapshot("05_personal_profile")
        tap("Continue")
        snapshot("06_trajectory")
        tap("Continue")
        snapshot("07_privacy_intro")
        tap("Continue")
        tap("Review privacy")
        snapshot("08_required_agreement")
        XCTAssertFalse(app.buttons["Continue to camera"].isEnabled)
        tap("I understand and agree")
        tap("Continue to camera")
        tap("Let’s take my selfie")
        snapshot("09_camera_fallback")
        tap("Close")
        XCTAssertTrue(app.buttons["I understand and agree"].waitForExistence(timeout: 10))
        tap("I understand and agree")
        tap("Continue to camera")
        tap("Let’s take my selfie")
        tap("Choose from gallery")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Allow Full Access")).firstMatch
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        _ = app.buttons["Cancel"].waitForExistence(timeout: 10)
        snapshot("10_photo_picker")
        finishPhotoAndOpenPaywall()
    }

    private func finishPhotoAndOpenPaywall() {
        // Fresh simulator Photos libraries may still be initializing. The
        // cancel button exists even on the loading screen, so it isn't a
        // sufficient readiness signal for a thumbnail coordinate tap.
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 60))
        // Verified first thumbnail in the dedicated QA photo library.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.24)).tap()
        XCTAssertTrue(app.buttons["Explore my Pro plans"].waitForExistence(timeout: 40))
        snapshot("11_real_analysis_locked_report")
        app.swipeUp()
        snapshot("12_locked_report_scrolled")
        tap("Explore my Pro plans")
        let yearly = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Yearly")).firstMatch
        XCTAssertTrue(yearly.waitForExistence(timeout: 25))
        snapshot("13_standard_paywall")
    }

    private func tryPaywallPlanSelection() {
        continueAfterFailure = false
        app.activate()
        for plan in ["Weekly,", "Monthly,", "Best value, Yearly,"] {
            let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", plan)).firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 15))
            card.tap()
        }
        XCTAssertTrue(app.buttons["Start free trial"].waitForExistence(timeout: 10))
        tap("Start free trial")
        snapshot("14_test_store_purchase_sheet")
    }

    private func scanAgain() {
        tap("Let’s take my selfie")
        tap("Choose from gallery")
        _ = app.buttons["Cancel"].waitForExistence(timeout: 10)
        finishPhotoAndOpenPaywall()
    }

    private func tryOfferExitRetryAndPurchase() {
        continueAfterFailure = false
        app.activate()
        tap("Cancel")
        XCTAssertTrue(app.buttons["Start free trial"].waitForExistence(timeout: 10))
        tap("Start free trial")
        tap("Test failed purchase")
        XCTAssertTrue(app.staticTexts["Purchase couldn't be completed. Please try again."].waitForExistence(timeout: 10))
        snapshot("15_failed_purchase_keeps_gate")
        tap("Close")
        let dialogue = app.buttons["miro.offer.surface"]
        XCTAssertTrue(dialogue.waitForExistence(timeout: 15))
        snapshot("16_private_offer_intro")
        for _ in 0..<3 { if dialogue.exists { dialogue.tap() } }
        let discount = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Private 50 percent off yearly offer")).firstMatch
        XCTAssertTrue(discount.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Weekly,")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Monthly,")).firstMatch.exists)
        snapshot("17_private_offer_three_plans")
        tap("Close")
        tap("Keep my offer")
        XCTAssertTrue(discount.exists)
        tap("Close")
        tap("Leave anyway")
        XCTAssertTrue(app.buttons["Let’s take my selfie"].waitForExistence(timeout: 10))
        snapshot("18_leave_returns_to_scan")
        scanAgain()
        XCTAssertFalse(discount.exists)
        tap("Close")
        XCTAssertTrue(app.buttons["Let’s take my selfie"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["miro.offer.surface"].exists)
        snapshot("19_consumed_offer_not_repeated")
        scanAgain()
        tap("Start free trial")
        tap("Test valid purchase")
        XCTAssertTrue(app.buttons["See your tips"].waitForExistence(timeout: 30))
        snapshot("20_purchased_original_report")
    }

    private func tryNavigationAndRestore() {
        continueAfterFailure = false
        app.activate()
        app.swipeUp()
        app.swipeUp()
        snapshot("21_report_categories")
        tap("See your tips")
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 10))
        snapshot("22_personalized_tips")
        tap("Home")
        tap("Scan again")
        tap("Close")
        XCTAssertTrue(app.buttons["Scan again"].waitForExistence(timeout: 10))
        tap("Start a new scan")
        tap("Close")
        tap("Progress")
        tap("Symmetry")
        tap("Overall")
        app.swipeUp()
        snapshot("23_progress_original_scan")
        tap("Tips")
        app.swipeUp()
        snapshot("24_tips_scrolled")
        tap("Profile")
        snapshot("25_pro_profile")
        let plans = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "View plans")).firstMatch
        XCTAssertTrue(plans.waitForExistence(timeout: 10))
        plans.tap()
        XCTAssertTrue(app.buttons["Restore Purchases"].waitForExistence(timeout: 20))
        tap("Restore Purchases")
        snapshot("26_restore_result")
    }

    private func verifyAnalyticsOptOutAndRelaunch() {
        let analytics = app.switches["Usage analytics"]
        XCTAssertTrue(analytics.waitForExistence(timeout: 10))
        XCTAssertEqual(analytics.value as? String, "1")
        // Backgrounding flushes opted-in events before the opt-out check.
        XCUIDevice.shared.press(.home)
        app.activate()
        analytics.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "value == %@", "0"), evaluatedWith: analytics)
        waitForExpectations(timeout: 5)
        snapshot("27_analytics_disabled")
        tap("Home")
        tap("Progress")
        tap("Tips")
        tap("Profile")
        XCTAssertFalse(app.buttons["Start free trial"].exists)
        app.terminate()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment = ["LOOKGRADE_ANALYTICS_QA": analyticsQA]
        app.launch()
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 20))
        XCTAssertFalse(app.buttons["analytics.allow"].exists)
        tap("Profile")
        app.swipeUp()
        XCTAssertTrue(analytics.waitForExistence(timeout: 10))
        XCTAssertEqual(analytics.value as? String, "0")
        snapshot("28_relaunch_preserves_pro_history_optout")
        tap("Home")
        XCUIDevice.shared.press(.home)
    }
}
