# Build plan

The order the app is built in. [spec.md](spec.md) says what each meter does; this file says
when. Every phase ends the same way:

1. `./scripts/check` passes, and new behavior has a test that fails without it.
2. A local commit (or a few, one logical change each).
3. `./scripts/deploy` runs the release on the 2015 MacBook Pro; check it is still running there.
4. CPU time of the release build over 30 s, measured on both Macs, goes in the commit body.

## Scope decisions

Settled with the owner on 2026-11-01:

- **Lean core first.** The main displays of each meter; the rest of the spec's display modes,
  image sets and colors come after phase 7.
- **No temperature yet.** It needs a private API on Apple silicon.
- **Core kinds are a setting.** `CPUConfig.groupsCoreKinds` shows performance and efficiency
  cores as two rows; off, one row averages every core.
- **CPU interval defaults to 2 s,** because each redraw is expensive on macOS 27
  ([0002](decisions/0002-draw-meters-as-button-subviews.md)).
- **Settings before the other meters,** so each meter adds its own settings as it is built.

## Phases

1. **Engine** (done). One timer for every meter (`MeterScheduler`), paused while the displays
   sleep; each meter its own status item.
2. **CPU meter** (done). Load per core, history, percentage and graph, redraw only on change.
   Menu: processor, cores, load per core kind, uptime, load average, Open Activity Monitor.
3. **Config file and settings window** (done). `~/.config/menumeters/config.json` holds one section
   per meter, each with an on/off switch. Read and written in Meters, off the main thread; a
   file that doesn't parse is logged and left alone, and the app runs on defaults until it is
   fixed. Hand edits apply while the app runs. The settings window has a tab per meter, starting
   with CPU: on/off, interval, percentage, graph, graph width, core kinds. A changed setting
   applies without a relaunch.
4. **Memory meter** (done). Pie and number displays from `host_statistics64`; the menu (free, used,
   total, wired, active, inactive, compressed, page-ins and page-outs, swap); its settings tab.
5. **Network meter** (done). Arrows and throughput from 64-bit `NET_RT_IFLIST2` counters, one buffer
   reused across ticks; the per-interface menu; its settings tab.
6. **Disk meter** (done). One activity light style from IOKit block storage statistics; volumes from
   IOKit matching notifications; the volume menu with open and eject; its settings tab.
7. **Extras** (done). Top processes in the CPU menu (`proc_pid_rusage`, sampled only while the menu is
   open), the hidden-meter notice on menu bar and screen changes, launch at login (LaunchAgent
   on macOS 12, `SMAppService` behind `#available` on 13 and later).
