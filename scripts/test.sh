#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$REPO_DIR"
mkdir -p .build
if [[ -e .build/UnitTests.xcresult ]]; then
  echo 'Move or remove .build/UnitTests.xcresult before starting a new run.' >&2
  exit 1
fi

# Create an isolated device compatible with an installed runtime.
IFS='|' read -r TEST_RUNTIME TEST_DEVICE_TYPE < <(python3 - <<'PY'
import json, subprocess, sys
def inventory(section):
    return json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', section, '-j']))
runtimes = [r for r in inventory('runtimes')['runtimes']
            if r.get('isAvailable') and '.iOS-' in r['identifier']
            and int(r['version'].split('.')[0]) >= 17]
runtimes.sort(key=lambda r: tuple(map(int, r['version'].split('.'))), reverse=True)
devices = inventory('devices')['devices']
types = inventory('devicetypes')['devicetypes']
for runtime in runtimes:
    phones = [d for d in devices.get(runtime['identifier'], [])
              if d.get('isAvailable') and d['name'].startswith('iPhone')]
    for phone in phones:
        device_type = phone.get('deviceTypeIdentifier')
        if not device_type:
            device_type = next((t['identifier'] for t in types if t['name'] == phone['name']), None)
        if device_type:
            print(runtime['identifier'] + '|' + device_type)
            sys.exit(0)
sys.exit('Install an iOS 17+ simulator runtime with an available iPhone device in Xcode.')
PY
)
TEST_DEVICE="$(xcrun simctl create LookGradeUnitTests "$TEST_DEVICE_TYPE" "$TEST_RUNTIME")"
[[ "$TEST_DEVICE" =~ ^[0-9A-Fa-f-]{36}$ ]] || exit 1
cleanup() {
  xcrun simctl shutdown "$TEST_DEVICE" >/dev/null 2>&1 || true
  xcrun simctl delete "$TEST_DEVICE" >/dev/null 2>&1 || true
}
trap cleanup EXIT
xcrun simctl boot "$TEST_DEVICE"
xcrun simctl bootstatus "$TEST_DEVICE" -b
xcodebuild test -project FaceRate.xcodeproj -scheme FaceRate \
  -configuration Debug -destination "platform=iOS Simulator,id=$TEST_DEVICE" \
  -derivedDataPath .build/Tests \
  -clonedSourcePackagesDirPath .build/SourcePackages \
  -onlyUsePackageVersionsFromResolvedFile -parallel-testing-enabled NO \
  -enableCodeCoverage YES -resultBundlePath .build/UnitTests.xcresult \
  CODE_SIGNING_ALLOWED=NO
