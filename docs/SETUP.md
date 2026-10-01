# Local setup

## Requirements

- macOS with Xcode and an iOS Simulator runtime.
- iOS/iPadOS 17+ deployment target; Swift 5 language mode.
- Network access for the first Swift Package Manager resolution and SDK-backed subscription screens.
- Python 3 for localization checks.

Local portfolio verification used Xcode 27.0 and the iOS 26.5 Simulator runtime. CI records the selected runner's Xcode version in its log; a local successful build does not imply that Xcode is accepted for a store submission.

## Open the maintained project

```sh
git clone https://github.com/numann44/LookGrade.git
cd LookGrade
open FaceRate.xcodeproj
```

Use the shared **FaceRate** scheme. Keep `FaceRate.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` checked in. The main project is maintained directly: there is no root `project.yml` to regenerate it.

The displayed app name is LookGrade. The module name, bundle identifier `com.lokman.facerate`, persisted storage keys, and existing product identifiers retain their historical names for update compatibility. For your own unrelated app, use your own bundle ID and service configuration; changing those values is not an account transfer or a migration of existing purchases.

## Simulator and device runs

Select an iOS 17+ simulator and press Run. The simulator does not provide a physical camera; use the gallery with a fixture when exercising real Vision analysis. The supplied synthetic portrait is at `Analytics/UITests/Fixtures/synthetic-demo-portrait.png` and its provenance is beside it.

For physical-device runs, select your authorized signing team in Xcode and configure the necessary capabilities. Real camera capture, permission delivery, notifications, and Apple's sandbox receipts require device validation.

## Subscription configuration

[`RevenueCatConfig.swift`](../FaceRate/App/RevenueCatConfig.swift) contains client SDK configuration. Debug defaults to RevenueCat Test Store. Release uses the App Store client key. The entitlement identifier is `pro`; product/package resolution is implemented by the paywall and entitlement model.

To exercise your own catalog, replace the client configuration with your own RevenueCat project and configure its products/offerings. Client SDK keys are not server admin credentials. Do not put secret server keys, signing files, or Apple private keys in this repository.

`FACERATE_RC_APP_STORE=1` switches a Debug run to the App Store configuration. Use it only when intentionally testing Apple's catalog and receipt path. A Test Store purchase proves the app's test flow, not availability or approval of a live Apple product.

## Optional analytics

Normal Debug runs and screen previews do not initialize Mixpanel. The analytics QA opt-in is `LOOKGRADE_ANALYTICS_QA=1`; configure your own ingestion project before enabling it. Release still requires the user's optional consent. Do not enable QA delivery merely to run the unit suite: its injected event sink is offline.

## Debug screen previews

In Xcode, Edit Scheme → Run → Arguments → Environment Variables, add:

```text
PREVIEW_SCREEN = home
```

Available values: `onboarding`, `consent`, `home`, `capture`, `first-scan-ready`, `first-scan-intro`, `report`, `tips`, `progress`, `profile`, and `paywall`.

Use a dedicated disposable simulator. Preview startup clears and seeds that installation's history and grants local test access. The hook is compiled only in Debug. It is useful for screen inspection, not a substitute for the onboarding or purchase journey. The simple preview contains five sample history entries; it does not recreate the full September marketing capture dataset.

Additional Debug reset hooks exist for onboarding and the one-time exit offer. Their exact behavior is in `FaceRateApp.swift`. Prefer a new simulator for a complete first-launch test instead of resetting an installation that contains valued records.

## Run checks

```sh
python3 scripts/check_localizations.py
bash scripts/test.sh
```

The test script selects an installed iOS runtime, creates its own simulator, and removes that simulator after the run. Results are stored in `.build/UnitTests.xcresult`. See [DEVELOPMENT.md](DEVELOPMENT.md) for the release build and UI-test harness.
