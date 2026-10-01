# Simulator release journey

Run `bash scripts/run_release_qa.sh` from the repository root. Requires Xcode,
the iOS 26.5 simulator runtime and an internet connection. The script creates a
new iPhone 17 Pro simulator and leaves it available for inspection. It does not
touch existing simulators or physical devices. To use another installed runtime,
set `LOOKGRADE_QA_RUNTIME` to its `simctl` identifier and, if needed,
`LOOKGRADE_QA_DEVICE_TYPE` to an installed device type; the tested layout remains
iPhone 17 Pro (402 × 874 points), English.

The installed app is Debug and uses RevenueCat Test Store. The test approves only
the SDK's **Test valid purchase** action, never an Apple payment sheet. Analytics delivery is disabled by default. To inspect development ingestion,
configure an owned test project and explicitly set `LOOKGRADE_ANALYTICS_QA=1`
in the test runner environment (`TEST_RUNNER_LOOKGRADE_ANALYTICS_QA=1` for
command-line xcodebuild). Such events are QA activity, not customer behavior. Each run needs a
fresh device/RevenueCat identity: an already subscribed identity is not a clean
onboarding test. Do not run individual journey stages or these tests in parallel.

The fixture is an existing AI-generated fictional adult portrait from this
project's marketing inputs, not a customer image. Import it only into this QA
device. No face fixture is bundled into the app by this test project.

The single test covers optional analytics refusal/acceptance, onboarding and
name entry, required agreement, camera close, gallery and real Vision analysis,
locked report scrolling, all three plans, purchase cancellation/failure,
private offer keep/leave, repeated scan without a repeated offer, successful
Test Store purchase, original report, Home/Progress/Tips/Profile, both scan
entry points, restore, analytics withdrawal and cold-launch persistence.

XCTest stores screenshots and accessibility snapshots in the `.xcresult` bundle.
The Photos picker uses a verified first-thumbnail coordinate because its remote
view doesn't expose thumbnail cells through this app's accessibility tree.

This separate project is already generated. `project.yml` can regenerate **this
UI-test harness only** with XcodeGen; never regenerate the maintained app project.
It is not part of the FaceRate Release archive scheme.
