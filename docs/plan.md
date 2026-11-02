# Build plan

The order the app is built in. [spec.md](spec.md) says what each meter does; this file says
when. Each phase ends with `./scripts/check` passing and a local commit.

## Scope decisions

Settled with the owner on 2026-11-01:

- **Lean core first.** The main displays of each meter; the rest of the spec's display modes,
  image sets and colors come after phase 7.
- **No temperature yet.** It needs a private API on Apple silicon.
- **Core kinds are a setting.** `CPUConfig.groupsCoreKinds` shows performance and efficiency
  cores as two rows; off, one row averages every core.

## Phases

1. **Engine** (done). One timer for every meter (`MeterScheduler`), paused while the displays
   sleep; each meter its own status item. Settings are the defaults in code.
2. **CPU meter** (done). Load per core, history, percentage and graph, redraw only on change
   ([0002](decisions/0002-draw-meters-as-button-subviews.md)). Menu: processor, cores, load
   per core kind, uptime, load average, Open Activity Monitor.
3. **Memory meter.** Pie and number displays; the menu.
4. **Network meter.** Arrows and throughput from 64-bit `NET_RT_IFLIST2` counters; the menu.
5. **Disk meter.** One activity light style; the volume menu with open and eject.
6. **Config file and settings window.** Load and save `config.json`; the settings window edits
   it, including `groupsCoreKinds`.
7. **Extras.** Top processes in the CPU menu, the hidden-meter notice, launch at login.
