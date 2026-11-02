# 0009. Replace yujitach's fork on the owner's Mac, measured side by side

- **Date:** 2026-11-02
- **Status:** accepted

## Context

The rewrite exists to cost less CPU than yujitach's fork
([0001](0001-swift-appkit-swiftpm-macos-12.md)), but the earlier records measure only the
rewrite against itself. This record compares the two directly before the owner's copy of
yujitach's MenuMeters 2.1.6.1 was replaced.

Measured on an M5 Max running macOS 26.6.2, with the release build of commit `5212606`
built for arm64 only. Both apps ran at the same time with their menus closed, showing CPU,
memory and network, with disk off. CPU time is each process's `ps -o cputime` before and after
a 60 s window, so it is accurate to 10 ms. Each row is the mean of two runs, and the runs
differed by 10 ms at most:

| CPU meter interval | Ours | Yujitach's (1 s) |
|---|---|---|
| 2 s, our default | 170 ms (0.3% of a core) | 490 ms (0.8%) |
| 1 s, matching yujitach's | 315 ms (0.5%) | 505 ms (0.8%) |

Our other settings were memory as a number at 10 s and network throughput at 2 s. Yujitach's
were the owner's saved settings, with the CPU meter at 1 s. Resident memory was about 105 MB
for each app.

## Decision

The rewrite replaces yujitach's fork in `/Applications` on the owner's Mac. With the CPU meter
at the same 1 s interval, it uses about 40% less CPU. At its 2 s default, it uses about a third
of what yujitach's uses.

## Alternatives considered

- **Keeping yujitach's fork until every spec feature is built:** both apps cost under 1% of a
  core, so the saving is small on this Mac. The rewrite already covers the meters the owner
  uses.

## Consequences

- The comparison covers closed menus only. Open menus, the disk meter and the 2015 MacBook Pro
  are not measured against yujitach's yet. Running the comparison there is the next check, since
  that Mac has the least CPU to spare.
- At the same interval, most of the remaining cost is AppKit's per-change snapshot of the status
  item ([0002](0002-draw-meters-as-button-subviews.md)), which both apps pay. Lowering it further
  means changing the menu bar less often, not sampling faster.
