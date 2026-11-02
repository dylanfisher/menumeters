# 0005. The disk meter checks every second by default, not every 0.3 s

- **Date:** 2026-11-01
- **Status:** accepted

## Context

Yujitach's disk meter checks for activity every 0.3 s. Ours redraws its light only when the
activity changes, but on an idle Mac background writes start and stop about once a second, and
each change of a status item costs about 11 ms on macOS 27
([0002](0002-draw-meters-as-button-subviews.md)). Measured on the M1 Max running macOS 27.2,
release build, CPU time of the app over 30 s with the other meters at their defaults:

| Disk meter | CPU time |
|---|---|
| Off | 260 ms |
| Every 0.3 s, light never redrawn | 360 ms |
| Every 0.3 s | 820 ms |
| Every 1 s | 340 ms |
| Every 2 s | 240 ms |

At 0.3 s the light costs about 2% of a core, most of it in redraws. On the 2015 MacBook Pro
with macOS 12.7.6 the 0.3 s meter took the app from 50 ms to 110 ms.

## Decision

The disk interval defaults to 1 s. The range stays yujitach's 0.1–5 s, so the 0.3 s light is one
setting away. This follows the CPU meter, which defaults to 2 s for the same cost.

## Alternatives considered

- **0.3 s, as yujitach's:** about 2% of a core on macOS 27 for a light.
- **Ignoring small transfers:** fewer redraws at 0.3 s, but the light would no longer show all
  activity, which is what it is for.
- **Holding the light on for a minimum time:** fewer changes, but it adds a timer of its own and
  shows activity that has stopped.

## Consequences

- A short burst of activity can light the light for up to a second after it ends, and two bursts
  in the same second show as one.
- If a later macOS makes a status item change cheaper, as macOS 12 is, revisit the default.
