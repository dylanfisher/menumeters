# Code map

Where things live, and how to find one before you build a second. Read this before creating any
new file.

This file describes **shape, not contents**: conventions and search commands, never an inventory.
An inventory would be a second copy of what the code already says, and it would go stale without
anyone noticing. If you catch yourself listing what exists here, stop. The search is the list.

## Find before you create

AGENTS.md principles 1–3 depend on this. None of them can be followed in a codebase you haven't
searched.

| Before adding… | Run |
|---|---|
| any named thing | `rg -i '<name>' --type swift` |
| a building block | `ls Sources/Base/` |
| a sampler, model type or store | `ls Sources/Meters/` |
| a view, window or controller | `ls Sources/Interface/` |
| a free function | `rg '^\s*(public )?func ' Sources/Base/` |
| a file or folder path | `rg 'AppPaths' Sources/` (every path is built from `AppPaths`) |
| a type | `rg '(struct\|class\|enum\|protocol\|actor) <Name>\b'` |

If a search turns up something close but not identical, that's the second occurrence. Use it or
duplicate it; don't abstract yet (principle 3).

## Tiers

| Tier | Path | What belongs here | May import |
|---|---|---|---|
| **base** | `Sources/Base` | Helpers with no app knowledge: text, math, the logger, the bundle ID. Foundation only. | nothing |
| **meters** | `Sources/Meters` | The samplers (CPU, memory, disk, network), their history and readings, the config store and paths. Calls Mach, IOKit and sysctl; no AppKit, so it is testable without a menu bar. | base |
| **interface** | `Sources/Interface` | AppKit views, view controllers, windows. No file-system calls. | meters, base |
| **app** | `Sources/App` | `main.swift`, `AppDelegate` (where every object is built and wired), `Info.plist`, `AppIcon.svg`. Kept thin. | everything |

**Dependency direction is one-way: app → interface → meters → base.** Never upward.

Each tier is a SwiftPM target, so `Package.swift` is the dependency map. The build rejects an
import of any target that isn't a declared dependency, and an upward dependency is a cycle, which
SwiftPM refuses. `scripts/arch` covers the rules the compiler can't see: no AppKit, SwiftUI, Cocoa
or Carbon import in Base or Meters, no file-system calls in Interface or App, and no path logged as
public. Each rule has a file in `scripts/arch-fixtures/` that breaks it, and the script fails if a
rule stops catching its fixture. A new rule gets a fixture in the same change.

A new target goes in `Package.swift`, this table and the paths line at the end of this file, in
one commit.

## Naming

- One type per file, named after it: `AppPaths.swift`. Extensions go in `Type+Topic.swift`.
- Tests mirror the tree: `Sources/Meters/AppPaths.swift` → `Tests/MetersTests/AppPathsTests.swift`.
- AppKit subclasses keep their AppKit suffix: `…WindowController`, `…View`, `…Panel`.
- Put the unit in a name where the type doesn't carry it: `delaySeconds`, `volumeDecibels`.

## Promotion

Things move between tiers deliberately, never by accident:

- **Third occurrence** → extract to the lowest tier all three callers can reach (principle 3).
- **Meters type loses its app knowledge** → it belongs in Base; move it down.
- **Base type grows a domain type or a config read** → it belongs in Meters; move it up.

A promotion is its own commit, separate from whatever work revealed it (principle 4).

<!-- paths: Sources/Base Sources/Meters Sources/Interface Sources/App -->
<!-- ↑ scripts/check verifies every path above exists. Keep it in sync with the Tiers table;
     a rename that misses this line fails the gate, which is the point. -->
