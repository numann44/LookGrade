# Development and verification

## Local checks

```sh
python3 scripts/check_localizations.py
bash scripts/test.sh
```

The localization checker validates key coverage, translated format arguments, nonempty strings, and camera/photo permission copy across the 11 shipped languages. It also checks localized strings referenced from Swift source.

The unit-test script creates an isolated simulator using an available iOS runtime and phone type, runs the shared FaceRate scheme with signing disabled, and writes `.build/UnitTests.xcresult`. It shuts down and deletes only the simulator it created. Remove or move an existing result bundle before repeating the command. Swift packages use the checked-in resolved versions.

For an unsigned Release compilation:

```sh
xcodebuild build -project FaceRate.xcodeproj -scheme FaceRate \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath .build/Release \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO
```

This checks compilation. It does not produce a signed distribution archive or submit to App Store Connect.

## Test map

| Suite | Behavior under test |
| --- | --- |
| `FaceScorerTests` | Eight categories, bounded scores, aggregation, yaw/openness perturbations |
| `ScanHistoryStoreTests` | History preservation, malformed entries, quota and deletion boundaries |
| `ScanResultPersistenceTests` | Complete result round trips and relocated capture paths |
| `LegacyDataMigratorTests` | Legacy Flutter preference migration |
| `FindingsCatalogTests` | Consistent localized finding generation |
| `LocalizationTests` | Localization behavior and catalogs |
| `MiroDialogueProgressTests` | Guided dialogue state |
| `AppAnalyticsTests` | Consent, filtering, lifecycle, and offline sink behavior |

The source snapshot passed **41 unit tests with zero failures** locally on October 1, 2026, using Xcode 27.0 and an isolated iPhone 17 Pro simulator on iOS 26.5. This is a fresh source compilation/test run. Historical release-journey evidence from September is distinct from the checks rerun for this repository publication.

## GitHub Actions

The [workflow](../.github/workflows/ci.yml) records the Xcode version, checks localization, runs unit tests, and builds an unsigned Release target. XCTest results are uploaded even after a failure when available. Concurrency cancels superseded runs on the same branch.

CI requires a macOS runner with an installed iOS simulator runtime. Device discovery uses the installed inventory rather than a hard-coded simulator name. The long subscription UI journey is intentionally separate from routine checks because it requires a clean SDK test identity and configured external services.

## Full simulator journey

The separate [UI-test project](../Analytics/UITests/README.md) exercises onboarding, optional analytics choices, camera/gallery, real Vision analysis, a locked report, paywall plans, Test Store cancellation/failure/success, restore, navigation, and cold-launch persistence.

```sh
bash scripts/run_release_qa.sh
```

Its default runtime is iOS 26.5 and phone type is iPhone 17 Pro; override `LOOKGRADE_QA_RUNTIME` and `LOOKGRADE_QA_DEVICE_TYPE` for your installed inventory. It creates a new simulator and retains it for inspection. The fixture is a synthetic adult portrait, not a customer photo. The harness records XCTest screenshots and accessibility snapshots in a result bundle.

Normal journey runs leave analytics delivery disabled. To audit SDK ingestion, first configure your own analytics project and explicitly opt in through the runner environment. See the UI-test README for the exact switch. Test Store activity is separate from Apple's sandbox and real billing.

## Known boundaries

- The scorer is heuristic. Unit tests validate software behavior, not scientific validity, demographic performance, or objective appearance judgments.
- The current Swift 5 build reports a non-Sendable `CaptureService` capture warning. A strict-concurrency migration remains engineering work; this repository does not mask the warning.
- Simulator cannot validate physical-camera quality, all permission behavior, thermal/performance characteristics, or every device/language combination.
- Device testing is needed for reminder delivery and Apple sandbox/TestFlight purchase and restore flows.
- Test Store success does not establish live product approval, localized price availability, receipt recovery, or successful monetary collection.
- The checked-in legal-site source and privacy manifest do not automatically update App Store metadata or provider-side retention/deletion policies.

## Working conventions

Keep one maintained app project and one canonical source file for each implementation. Do not regenerate the app from the UI harness's XcodeGen specification. Check in the package lock and localized resources; exclude derived data, exports, signing material, scratch captures, and duplicated Swift files.

For behavior changes, add or adjust a focused regression test. For documentation or asset-only changes, validate links, provenance, rendering, and the affected file set without inventing implementation-mirroring tests.
