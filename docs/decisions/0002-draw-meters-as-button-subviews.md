# 0002. Draw meters as status item button subviews, and spend effort on skipping redraws

- **Date:** 2026-11-01
- **Status:** accepted

## Context

The spec planned to skip unchanged redraws, with yujitach's new `NSImage` per tick as the cost
to beat. Measured on an M1 Max running macOS 27.2 with one display, release build, CPU time of
the app's process over 30 s with the CPU meter ticking once a second:

| What changes each tick | CPU time |
|---|---|
| A subview of the button, redrawn | ~400 ms |
| `button.image`, swapped between two images made once | 340 ms |
| Nothing (sampling only) | 20 ms |

`sample` shows where a change goes: `NSStatusItem` re-renders the button into a snapshot for its
"replicant" (`_updateReplicant`, `_cacheDisplayInRect`) and commits a Core Animation
transaction. That is about 11 ms per change whatever is drawn, and sampling plus the comparison
is under 1 ms a second.

## Decision

Each meter draws in an `NSView` added to its status item's button, and redraws only when its
pixel-rounded state (`CPUDrawState`) changes. Lowering the cost per tick means changing the
status item less often, not drawing it differently.

## Alternatives considered

- **`button.image`, rebuilt on change:** costs the same per change, and a colored image doesn't
  follow each menu bar's appearance; the meter would have to watch appearance changes itself. A
  template image would follow it but can't show the user and system colors.
- **Drawing into a reused bitmap:** the cost is in AppKit's snapshot, after our drawing, so it
  saves nothing measurable.

## Consequences

- A graph scrolls every tick, so a meter showing one changes every tick. The interval sets most
  of the cost: 1 s costs about 1.3% of a core on this Mac, 2 s about half that.
- A percentage alone changes only when the whole percent does, so an idle Mac redraws rarely.
- On the 2015 MacBook Pro with macOS 12.7.6, the same release build with the graph redrawing
  every second takes 50 ms over 30 s, about an eighth of the macOS 27 cost, so the snapshot cost
  is a newer macOS's. Skipping redraws still pays on both.
