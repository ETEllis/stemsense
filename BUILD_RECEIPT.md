# StemSense build receipt

Date: July 20, 2026  
Toolchain: Xcode 27  
Targets: iPhone + iPad, iOS/iPadOS 18+

## Verified after the StemSense rebrand

- XcodeGen regenerated `StemSense.xcodeproj` and the shared `StemSense` scheme.
- Universal SwiftUI app and embedded Safari Web Extension: **BUILD SUCCEEDED**.
- Generic iOS Simulator test products, including the unit-test bundle: **BUILD FOR TESTING SUCCEEDED**.
- Generic physical-device (`iphoneos`, arm64) unsigned build: **BUILD SUCCEEDED**.
- The app icon catalog consumes the new 1024 px StemSense production mark.
- Product name, target names, bundle identifiers, URL scheme, extension metadata, and user-facing copy were migrated from the prior working title.
- Safari JavaScript syntax, property lists, and Web Extension JSON validate successfully.
- No local Apple team identifier, device identifier, provisioning profile, API key, token, or environment file is included in the repository.

## Previously verified mechanism harness

- Separable synthetic left/right signals produced 100% leave-one-out accuracy.
- Identical adversarial signals produced 50% accuracy and failed the 85% arm gate.
- Ambiguous identical-signal prediction produced zero confidence.
- Split Stem Lab, visible system-volume bridge, calibration workflow, confidence fallback, and accelerated seek path compile together.

## Requires physical-device acceptance

- AirPods double/triple-press seek behavior.
- StemSense left/right calibration and blind classification trial.
- System-volume rollback latency and audible stability.
- `youtube.com` Safari permission confirmation.
- Signed installation using the developer's own Xcode account and provisioning profiles.

See `DEVICE_INSTALL.md` for the reusable installation path.
