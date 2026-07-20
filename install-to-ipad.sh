#!/bin/zsh
set -euo pipefail

STEMSENSE_ROOT="${0:A:h}"
STEMSENSE_DERIVED="${TMPDIR:-/tmp}/StemSenseDeviceBuild"

: "${STEMSENSE_TEAM_ID:?Set STEMSENSE_TEAM_ID to your Apple development team ID.}"
: "${STEMSENSE_XCODE_DEVICE_ID:?Set STEMSENSE_XCODE_DEVICE_ID to the destination ID shown by xcodebuild -showdestinations.}"
: "${STEMSENSE_CORE_DEVICE_ID:?Set STEMSENSE_CORE_DEVICE_ID to the identifier shown by xcrun devicectl list devices.}"

if ! xcrun devicectl list devices | grep -q "$STEMSENSE_CORE_DEVICE_ID.*available"; then
  echo "The requested iPhone or iPad is not currently available to Xcode."
  echo "Unlock it, enable Developer Mode, and connect it by USB or the paired Wi-Fi connection."
  exit 2
fi

xcodebuild \
  -project "$STEMSENSE_ROOT/StemSense.xcodeproj" \
  -scheme StemSense \
  -sdk iphoneos \
  -destination "id=$STEMSENSE_XCODE_DEVICE_ID" \
  -derivedDataPath "$STEMSENSE_DERIVED" \
  DEVELOPMENT_TEAM="$STEMSENSE_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates \
  build

xcrun devicectl device install app \
  --device "$STEMSENSE_CORE_DEVICE_ID" \
  "$STEMSENSE_DERIVED/Build/Products/Debug-iphoneos/StemSense.app"

echo "StemSense is installed. Open it once, then enable its Safari extension in Settings."
