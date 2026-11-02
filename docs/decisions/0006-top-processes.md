# 0006. Top processes from proc_pid_rusage, the user's own processes only

- **Date:** 2026-11-01
- **Status:** accepted

## Context

The CPU menu lists the processes using the most CPU. Yujitach's fork runs `/usr/bin/top` and
parses its output, which costs a process launch and a text parse per update. The spec and plan
call for `proc_pid_rusage` instead, sampled only while the menu is open.

`/usr/bin/top` is setuid root, so it sees every process. `proc_pid_rusage`, and every other
`libproc` call that reports CPU time, refuses another user's process to a process without root:
on an M1 Max running macOS 27.2 it read 443 of 754 processes, and refused the rest, among them
WindowServer, `kernel_task`, `mds_stores` and the other daemons that run as root or as their own
users.

## Decision

The list comes from `proc_pid_rusage` and shows the user's own processes, five by default, each
as a share of one core over the time since the last sample, the first after half a second. Apps
show their own name and icon. The CPU times come in Mach time units, so they are converted with
`mach_timebase_info`: 125/3 of a nanosecond each on Apple silicon, one on Intel.

## Alternatives considered

- **Parsing `/usr/bin/top`, as yujitach's fork does:** sees system processes, but launches a
  process for each update while the menu is open. The spec lists it as a cost to avoid.
- **A privileged helper:** needs installing a root daemon and an entitlement, far outside the
  lean scope.

## Consequences

- When WindowServer or a system daemon is what is busy, the list doesn't show it; the per-kind
  load lines above it still show the total.
- If seeing system processes matters, the choice is between `top` while the menu is open and a
  privileged helper; both need the owner's decision.
