# AGENTS.md

Instructions for AI coding agents working in this repo. Humans: see [README.md](README.md).

**Keep this file to 50 lines or fewer** (`scripts/check` enforces it); move longer text to `docs/`.

## Stack

- **Language:** Swift 6 (mode 6, tools 6.2), AppKit, Swift Testing; Xcode in `.xcode-version`
- **Target:** macOS 12+ so a 2015 Intel MacBook Pro runs it; universal, tuned for Apple silicon.
  macOS 13+ APIs (`@Observable`, `SMAppService`, `OSAllocatedUnfairLock`) only behind `#available`.
- **Behavior:** yujitach's MenuMeters, rewritten for efficiency: [docs/spec.md](docs/spec.md)
- **Build:** SwiftPM only, no `.xcodeproj` or package dependencies. Tiers: [map](docs/map.md)

## Commands

| Task | Command |
|---|---|
| Set up a clone | `./scripts/setup` |
| Build and launch the app | `./scripts/dev` |
| Run tests | `./scripts/test` (`--filter <name>` for one) |
| Fix formatting | `./scripts/format` |
| **Full gate** | `./scripts/check` |

## Principles ([rationale](docs/principles.md))

1. **Single source of truth.** Define every fact once. **Search before you create:** map.md.
2. **Match the surrounding code.** Read a neighboring file before writing a new one.
3. **DRY on the third occurrence, not the second.** A wrong abstraction costs more.
4. **Smallest change that solves the problem.** No drive-by refactors outside the task.
5. **Fail loudly.** No empty catches, no silent fallbacks, no defaults that mask a missing value.
6. **Delete, don't comment out.** Git remembers.
7. **No new dependencies without asking first.** Say what it's for and what it replaces.
8. **Style is the formatter's job.** If a tool enforces it, it does not belong in review.

## Boundaries

- `Package.swift` is the tier map. Never add a dependency that points up a tier.
- No file-system I/O on the main thread or in Interface and App; `scripts/arch` checks the calls.
- Tests never touch the user's real files; build `AppPaths(home:)` on a temporary folder.
- The sampling tick is the budgeted path: no allocation per tick, no redraw of an unchanged meter.
- Commit locally; never push or call `gh`. The owner pushes.
- **Pre-release:** breaking changes are fine. Stored data has one shape, with no version fields
  or migrations; data that doesn't match is discarded. Delete this line at the first release.

## Definition of done

- `./scripts/check` passes clean, and new behavior has a test that fails without the change.
- No new dependencies, no new files outside [docs/map.md](docs/map.md)'s layout, no TODOs.
- Record non-obvious decisions in `docs/decisions/`. Write per [docs/writing.md](docs/writing.md).
