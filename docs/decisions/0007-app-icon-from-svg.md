# 0007. The app icon is an SVG, rendered to .icns at bundle time with AppKit

- **Date:** 2026-11-01
- **Status:** accepted

## Context

The app needs an icon for Finder, Login Items, Spotlight and the About window. macOS 12 reads
an `.icns` file named by `CFBundleIconFile`. The project builds with SwiftPM only, with no
`.xcodeproj`, so there is no asset catalog step, and it adds no dependencies without asking.
The icon was designed as an SVG (sketch M6, round 16 of the icon tests).

## Decision

`Sources/App/AppIcon.svg` is the only copy of the icon. `scripts/bundle` renders it with
`scripts/render-icon.swift`, which draws it with `NSImage` at each size macOS asks for, packs the
sizes with `iconutil`, and copies the result into the bundle. It renders again only when the SVG
is newer than `.build/AppIcon.icns`.

## Alternatives considered

- **Commit the `.icns`** — rejected: a binary copy of the SVG that can drift from it, and a
  change to the icon becomes a diff nobody can review.
- **Render with `rsvg-convert` or ImageMagick** — rejected: a Homebrew dependency for every
  clone, where AppKit already draws this SVG to match the browser render.
- **An asset catalog through `actool`** — rejected: it needs an Xcode project or a hand-written
  catalog, and an `.icns` covers every macOS version the app supports.

## Consequences

AppKit's SVG support is a subset of SVG. A change to the icon that uses filters, masks or text
should be checked in the built bundle, not only in a browser. The render runs on the build Mac,
so the macOS 12 test Mac never needs to read the SVG.
