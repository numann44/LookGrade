#!/bin/bash
set -euo pipefail

# Always creates an isolated simulator. Never erases a phone or existing device.
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test -f "${REPO_DIR}/FaceRate.xcodeproj/project.pbxproj"
test -f "${REPO_DIR}/Analytics/UITests/Fixtures/synthetic-demo-portrait.png"
cd -- "${REPO_DIR}"
QA_RUNTIME="${LOOKGRADE_QA_RUNTIME:-com.apple.CoreSimulator.SimRuntime.iOS-26-5}"
QA_DEVICE_TYPE="${LOOKGRADE_QA_DEVICE_TYPE:-com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro}"
QA_DEVICE="$(xcrun simctl create LookGradeReleaseQA "${QA_DEVICE_TYPE}" "${QA_RUNTIME}")"
[[ "${QA_DEVICE}" =~ ^[0-9A-Fa-f-]{36}$ ]] || { echo "Unexpected simulator ID"; exit 1; }
QA_RESULTS="$(mktemp -d /tmp/lookgrade-qa.XXXXXX)"
[[ "${QA_RESULTS}" == /tmp/lookgrade-qa.* ]] || exit 1
echo "Dedicated simulator: ${QA_DEVICE}"
echo "Test results: ${QA_RESULTS}"
xcrun simctl boot "${QA_DEVICE}"
xcrun simctl bootstatus "${QA_DEVICE}" -b
xcodebuild build -project FaceRate.xcodeproj -scheme FaceRate \
  -configuration Debug -destination "platform=iOS Simulator,id=${QA_DEVICE}" \
  -derivedDataPath .build/ReleaseQA CODE_SIGNING_ALLOWED=NO
xcrun simctl install "${QA_DEVICE}" .build/ReleaseQA/Build/Products/Debug-iphonesimulator/FaceRate.app
xcrun simctl addmedia "${QA_DEVICE}" Analytics/UITests/Fixtures/synthetic-demo-portrait.png
xcodebuild test -project Analytics/UITests/LookGradeQA.xcodeproj -scheme LookGradeQA \
  -destination "platform=iOS Simulator,id=${QA_DEVICE}" -parallel-testing-enabled NO \
  -derivedDataPath .build/AnalyticsUITests \
  -only-testing:LookGradeUITests/LookGradeUITests/testFullReleaseJourney \
  -resultBundlePath "${QA_RESULTS}/Journey.xcresult"
echo "PASS. Simulator retained for inspection: ${QA_DEVICE}"
echo "Screenshots and test results: ${QA_RESULTS}/Journey.xcresult"
