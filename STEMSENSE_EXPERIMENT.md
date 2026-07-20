# StemSense physical verification protocol

StemSense is an experimental inference layer for Split Stem. It does not claim that iOS exposes a per-ear touch event. It predicts the touched side by aligning a system-volume change with the surrounding AirPods motion and optional contact-audio energy.

## Hypotheses

### H1 — Motion asymmetry

A natural swipe on the left stem produces a measurably different short-window rotation and acceleration signature from a natural swipe on the right stem for the same wearer.

Pass condition: leave-one-out calibration accuracy is at least 85% with 12 samples per side.

### H2 — Contact asymmetry

When the AirPods microphone is fixed to the configured scrub side, short-window contact energy improves left/right separability.

Pass condition: Contact Assist improves held-out accuracy or runtime confidence without increasing false scrub events.

### H3 — Volume rollback

After a scrub-side prediction, the visible `MPVolumeView` can return system volume to its pre-gesture value quickly enough that the swipe is experienced primarily as timeline movement.

Pass condition: restored volume is within one system notch of baseline and the scrub action fires once.

### H4 — Safe uncertainty

Ambiguous signals remain ordinary volume changes rather than becoming accidental seeks.

Pass condition: predictions below the configured confidence margin never scrub or roll volume back.

## Calibration

1. Connect both AirPods Pro 3 and keep system volume between 25% and 75%.
2. Open StemSense → **Split Stem Lab**.
3. Choose the intended scrub side.
4. Calibrate the left stem with 12 natural swipes, alternating up and down.
5. Change head posture slightly, then calibrate the right stem with 12 swipes.
6. Record the reported held-out accuracy.
7. If accuracy is below 85%, enable Contact Assist, set the AirPods microphone to **Always Left** or **Always Right** matching the scrub side, and recalibrate.

## Blind trial

Arm Split Stem and perform a randomized sequence unknown to the observer:

- 20 volume-side swipes
- 20 scrub-side swipes
- 10 swipes while slowly turning the head
- 10 ordinary head turns with no stem contact

Record each result from the live inference feed.

Acceptance thresholds:

- at least 90% correct side predictions in the first 40 trials
- zero scrubs from the 10 no-touch head movements
- at most one false scrub among 20 volume-side swipes
- at least 18 of 20 scrub-side swipes produce exactly one seek

## Targeted counterexamples

Test these explicitly rather than assuming calibration generalizes:

- using the opposite hand across the face
- walking, chewing, nodding, or speaking during a swipe
- wearing only one AirPod
- loose versus firmly seated AirPods
- volume at 0% or 100%, where a same-direction swipe may produce no observable volume delta
- Automatic Microphone versus a fixed microphone side
- music paused versus playing

Any counterexample that pushes held-out or blind accuracy below the gate keeps Split Stem experimental. The existing double-press/triple-press controls remain the production fallback.

## Current scope

The inference-to-scrub path controls the StemSense player. Safari and arbitrary third-party media require an additional continuously reachable command bridge and will not be claimed until separately demonstrated on-device.
