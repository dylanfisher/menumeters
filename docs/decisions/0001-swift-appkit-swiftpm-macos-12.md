# 0001. Swift, AppKit and SwiftPM, targeting macOS 12 as a universal binary

- **Date:** 2026-11-01
- **Status:** accepted

## Context

MenuMeters is a rewrite of [yujitach/menumeters](https://github.com/yujitach/menumeters), an
Objective-C app built from an Xcode project. The rewrite exists to cost less CPU and energy per
tick, and it has to run on the owner's 2015 Intel MacBook Pro, whose last macOS is 12.7.6, as
well as on Apple silicon Macs, which are the priority. It ships as a direct download from GitHub
Releases under GPL-2.0. The owner's other Swift apps follow `~/projects/app-conventions`.

## Decision

Swift 6 in language mode 6, AppKit built in code, Swift Testing, and SwiftPM alone, started from
the app-conventions templates. The deployment target is macOS 12. Release bundles are universal
(arm64 and x86_64) from `scripts/bundle -a universal`; debug builds are native only. Each Mac runs
its own slice, so Apple silicon gets native code with nothing given up for Intel.

The middle tier is `Meters` rather than the template's `Core`. There is no command registry or
palette: the app has a handful of actions, which the guide lists as the case to skip them.

## Alternatives considered

- **SwiftUI `MenuBarExtra`:** needs macOS 13, and redrawing through SwiftUI costs more than
  drawing the meter into the status item ourselves.
- **XcodeGen or a checked-in `.xcodeproj`:** the owner wants as little Xcode as possible, and
  SwiftPM builds everything this app needs, a menu bar app with no extensions.
- **Separate builds for Apple silicon and Intel:** two downloads and two things to test, for no
  gain over a universal binary. Revisit only if profiling shows the macOS 12 code paths cost
  Apple silicon something.
- **macOS 14, the app-conventions default:** would drop the 2015 MacBook Pro. music-player and
  photo-screensaver target 12 for the same Mac.
- **Porting yujitach's code:** the rewrite starts fresh and uses theirs as a behavior reference
  ([docs/spec.md](../spec.md)), which avoids carrying their per-file copyright notices.

## Consequences

- No `@Observable`: models report changes through closures, as music-player does.
- No `SMAppService` on macOS 12: launch at login needs a LaunchAgent there, or an `#available`
  branch.
- No `OSAllocatedUnfairLock` or `Mutex`: use `os_unfair_lock` or `NSLock`.
- The macOS 13 `URL` APIs (`URL(filePath:)`, `URL.homeDirectory`) are out; `AppPaths` uses the
  older forms.
- A universal build needs full Xcode, pinned in `.xcode-version`, locally and in CI.
