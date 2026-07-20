# Split Stem

Status: experimental inference implementation complete; physical validation pending  
Product target: StemSense 1.1 Lab → StemSense 2.0 after acceptance gates

## Product contract

The user assigns one AirPod as the **volume anchor** and the other as the **scrub stem**.

- Left volume / right scrub, or right volume / left scrub
- Swipe the volume anchor up or down to change system volume normally
- Swipe the scrub stem forward or backward to move continuously through the active media item
- Slow swipe: frame-scale precision
- Normal swipe: second-scale movement
- Fast swipe: accelerated movement through long media
- Release the stem to commit the seek and resume the prior play/pause state
- Double-press and triple-press remain the ten-second fallback

The preference follows the AirPods pair, not the phone, so the assignment remains stable across iPhone and iPad.

## Required Apple capability

StemSense needs a user-authorized public event that preserves input provenance before the system converts the gesture into volume:

```swift
struct HeadphoneTouchEvent {
    enum Side { case left, right }
    enum Gesture {
        case swipe(delta: Double, velocity: Double, phase: GesturePhase)
        case press(count: Int)
    }

    let accessoryIdentifier: UUID
    let side: Side
    let gesture: Gesture
}
```

It also needs a system preference that lets the user assign Volume Swipe per stem instead of enabling or disabling both stems together.

## Current public API gap

- AirPods Pro 2 and 3 expose `Volume Swipe` as one global accessibility setting.
- `AVAudioSession.outputVolume` exposes only the resulting systemwide scalar and is read-only to the app.
- The volume-change observation contains no left/right source, gesture phase, distance, or velocity.
- `CMHeadphoneMotionManager` exposes processed head motion, not touch-control input.
- `MPRemoteCommandCenter` exposes discrete media commands such as next, previous, and seek; AirPods volume swipes do not arrive as these commands.

Because both stems collapse into the same undifferentiated volume change, an app cannot preserve one as volume while reliably remapping the other. A side selector in the current app would therefore be nonfunctional.

## StemSense inference bridge

StemSense 1.1 now attacks the missing provenance indirectly:

1. Observe the system-volume transition to detect swipe direction and notch size.
2. Capture a short AirPods motion window around the transition.
3. Optionally capture high-quality AirPods microphone energy with the microphone fixed to one side.
4. Train a personalized standardized nearest-centroid classifier on 12 left and 12 right swipes.
5. Require at least 85% leave-one-out accuracy before enabling runtime translation.
6. Preserve low-confidence events as volume.
7. For a confident scrub-side event, restore the previous volume through the visible system volume control and map gesture energy to an accelerated seek.

This does not manufacture a raw touch event. It creates a falsifiable probabilistic estimate and refuses to arm when the wearer, fit, environment, or hardware does not produce enough asymmetry.

## Capability gate

When Apple introduces the required event, StemSense should replace inference with direct provenance after all four checks pass:

1. Connected accessory reports per-stem touch-event support.
2. The user grants headphone-control permission.
3. The active player reports continuous-seek support.
4. StemSense successfully claims the scrub stem without disabling the configured volume anchor.

If any check fails, StemSense keeps its existing double-press `+10 seconds` and triple-press `−10 seconds` behavior.

## Feedback Assistant request

**Title:** Allow user-authorized per-ear AirPods touch gestures for active media apps

**Request:** Add a public, privacy-gated API that reports the originating AirPod, gesture phase, direction, distance, and velocity to the active Now Playing app. Extend AirPods settings so Volume Swipe can be enabled independently for the left and right stems. This would let media and accessibility apps offer continuous scrubbing, timeline navigation, reading-position control, and other user-selected actions while retaining volume on the opposite stem.
