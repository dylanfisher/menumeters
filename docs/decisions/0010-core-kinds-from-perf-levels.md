# 0010. Name core kinds from macOS's performance levels, matched to cluster-type letters

- **Date:** 2026-11-02
- **Status:** accepted

## Context

The CPU meter grouped cores into performance and efficiency, read from each CPU's
`cluster-type` letter in the device tree, `P` or `E`. An M5 Max has neither efficiency cores
nor only those letters: 6 "Super" cores with letter `P` and 12 "Performance" cores with letter
`M`. The unknown `M` made the topology fail, so the meter treated all 18 cores as one kind and
the core-kinds setting did nothing.

macOS names each kind in `hw.perflevelN.name`, fastest first, with its CPU count in
`hw.perflevelN.logicalcpu`. The device tree gives no level number per CPU, only the letter.

## Decision

`CoreTopology` holds a list of kinds, fastest first, each with macOS's name and its CPUs. The
letters present are ranked `P`, `M`, `E`, fastest first, and matched to the performance levels
in order. The match must agree on every level's CPU count, or the topology fails as before.
The menu and the meter show one line or row per kind, named as macOS names it.

## Alternatives considered

- **Treating `M` as efficiency:** labels the M5 Max's Performance cores "Efficiency", and
  breaks again when a chip has three kinds.
- **Matching letters to levels by CPU count alone:** fails when two kinds have the same count.

## Consequences

- A chip with a new letter fails the topology, logs it, and shows one row until the letter is
  added to `CoreTopology.clusterTypesFastestFirst`.
- A chip with three kinds shows three rows.
