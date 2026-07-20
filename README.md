<p align="center">
  <img src="Brand/StemSense-lockup-dark.svg" alt="StemSense" width="760">
</p>

<p align="center"><strong>Your AirPods stems should control the moment—not just the volume.</strong></p>

StemSense turns ordinary AirPods media commands into ten-second navigation and explores the harder interaction Apple does not expose directly: keep one stem anchored to volume while the other becomes a tactile media scrubber.

## What works now

- **Double-press:** seek forward 10 seconds.
- **Triple-press:** seek backward 10 seconds.
- **Single-press:** keep normal play/pause behavior.
- **Safari route:** remap compatible YouTube playback through a Safari Web Extension.
- **Focused-player route:** paste a YouTube URL into the app and control its supported IFrame player through `MPRemoteCommandCenter`.
- **Split Stem Lab:** train a private, on-device classifier to distinguish left-stem and right-stem interaction from system-volume change, AirPods motion, and optional short-lived contact-audio energy.

The classifier must pass an 85% leave-one-out accuracy gate before split-stem mode can arm. Low-confidence events fail safe as ordinary volume changes.

## The product idea

In split-stem mode, the user chooses one AirPod as the fixed **volume anchor**. A swipe on the other stem becomes a continuous media scrub gesture:

- short swipe → precise seek
- longer or faster swipe → accelerated seek
- anchor-stem swipe → ordinary system volume

iOS currently collapses both AirPods volume swipes into the same systemwide volume signal and does not publish raw per-ear stem events to third-party apps. StemSense therefore uses a personalized sensor-fusion experiment rather than pretending that public iOS APIs provide provenance they do not. The direct press-to-seek routes are production-real; split-stem inference remains explicitly gated experimental behavior until it passes physical-device acceptance.

## Build

Requirements: Xcode 27+, iOS/iPadOS 18+, XcodeGen 2.43+, and a free or paid Apple development identity.

```bash
xcodegen generate
open StemSense.xcodeproj
```

Then select the **StemSense** target, choose your development team, connect an iPhone or iPad, and press Run. For the Safari route, enable **Settings → Apps → Safari → Extensions → StemSense** and allow access to `youtube.com`.

`install-to-ipad.sh` automates the physical-device build and install after the matching Apple account and provisioning profiles are present in Xcode.

## Repository map

- `StemSense/Player/` — playback bridge, Now Playing state, and remote command routing
- `StemSense/StemSense/` — sensor fusion, calibration, classifier, and volume rollback
- `StemSense Extension/` — Safari Web Extension for compatible YouTube playback
- `StemSenseTests/` — URL parser and classifier acceptance coverage
- `Brand/` — canonical SVG mark, wordmark lockups, app icon, and retained concepts
- `STEMSENSE_EXPERIMENT.md` — experiment contract and physical-device protocol
- `SPLIT_STEM_SPEC.md` — capability boundary and release gates
- `BUILD_RECEIPT.md` — latest local verification receipt

## Privacy

StemSense does not request a YouTube login, store viewing history, inject or block ads, or download media. Calibration features are computed locally. Optional contact-audio assistance stores energy features only; it does not store microphone audio. See [PRIVACY.md](PRIVACY.md).

## Status

The universal app, Safari extension, focused player, classifier harness, and unsigned device build are implemented and verified locally. Signed installation still requires an Xcode account authorized for the selected development team and fresh provisioning profiles. See [DEVICE_INSTALL.md](DEVICE_INSTALL.md).

StemSense is an independent product and is not affiliated with or endorsed by Apple, AirPods, Google, or YouTube.
