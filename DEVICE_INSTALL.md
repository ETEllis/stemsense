# Physical-device installation

The complete app and Safari extension compile for generic `iphoneos` without signing. Installing on a specific iPhone or iPad additionally requires an Apple development identity, an Xcode account authorized for the same team, and provisioning profiles for the app and extension bundle identifiers.

## Xcode route

1. Open Xcode → **Settings → Accounts** and add your Apple account.
2. Open `StemSense.xcodeproj`.
3. Select the **StemSense** target → **Signing & Capabilities** → choose your development team.
4. Repeat for **StemSense Extension**.
5. Connect and unlock the device, select it as the run destination, and press Run.
6. On-device, enable **Settings → Apps → Safari → Extensions → StemSense** and allow `youtube.com`.

## Command-line route

Discover the required identifiers:

```bash
xcodebuild -project StemSense.xcodeproj -scheme StemSense -showdestinations
xcrun devicectl list devices
```

Then run:

```bash
export STEMSENSE_TEAM_ID="YOUR_TEAM_ID"
export STEMSENSE_XCODE_DEVICE_ID="XCODE_DESTINATION_ID"
export STEMSENSE_CORE_DEVICE_ID="DEVICECTL_IDENTIFIER"
./install-to-ipad.sh
```

The helper intentionally ships without local account or device identifiers.
