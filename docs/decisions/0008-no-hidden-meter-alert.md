# 0008. No alert when macOS hides a meter

- **Date:** 2026-11-01
- **Status:** accepted

## Context

Yujitach's fork alerts the user when a crowded menu bar hides a meter. The rewrite added the
same alert (`ee47742`), which read each status item's window: no screen, or an occlusion state
without `.visible`, counted as hidden. On the 2015 MacBook Pro the alert named the CPU, Memory
and Network meters every time a screensaver app started, though nothing was hidden for long.

## Decision

The app never shows the alert. The check, its window reading and its tests are removed.

## Alternatives considered

- **Skip the check while another app covers the screen** — rejected: each new app that takes
  over the screen in its own way is another false alarm to chase, and macOS 27 gives no list
  of status item windows to check against instead.
- **A setting to turn the alert off** — rejected: a setting to hide a feature that misfires.

## Consequences

A user whose menu bar is too full sees fewer meters and no explanation. Holding Command and
dragging the meters, as for any menu bar item, still works.
