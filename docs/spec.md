# Behavior spec

What MenuMeters does, taken from [yujitach/menumeters](https://github.com/yujitach/menumeters), the
fork this app rewrites. The behavior is theirs; the code is new. Where their implementation is
better than what we would write, use the same approach and say so in a comment. Where it is
worse, the "Efficiency" section says what we do instead. [plan.md](plan.md) has the build order.

## Meters

Four meters, each its own status item, each switched on or off on its own.

### CPU

- **Display modes,** combinable: percent, graph, vertical thermometer, horizontal thermometer.
  Percent comes large, small (default) or split.
- **Settings:** interval 0.5–10 s (default 1 s); graph width 11–88 px (default 33); horizontal
  rows; menu width; average all cores, sum across cores, or average the lower half; sort cores
  by usage; user and system colors; temperature with sensor, color and °C/°F; top processes
  0–25 (default 5).
- **Menu:** processor and core description, uptime, task and thread counts, load average, CPU
  power limit, the top processes with app icons, Open Activity Monitor, Open Console, Settings.

### Memory

- **Display modes:** pie (default), bar, graph, number.
- **Settings:** interval 1–60 s (default 10 s); used or free label; memory pressure; paging
  indicator; graph width; colors for free, used, active, inactive, wired, compressed, page-in and
  page-out.
- **Menu:** free, used and total; wired, active, inactive and compressed; page-ins and page-outs;
  swap used and swap files.

### Disk

- **Display:** an activity light, not a throughput graph. Image sets: color arrows, arrows,
  lights, aqua lights, disk arrows, large disk arrows.
- **Settings:** interval 0.1–5 s (default 0.3 s); clicking a volume opens or ejects it, with ⌥
  inverting the choice; base-2 sizes.
- **Menu:** mounted volumes with icon, used and free space, open or eject.

### Network

- **Display modes,** combinable: arrows (default), throughput text, graph.
- **Settings:** interval 0.5–20 s (default 2 s); send/receive orientation; throughput label;
  bits or bytes; graph style (standard, centered, opposed, inverse opposed); scale to interface
  speed or peak traffic; scale curve (linear, square root, cube root (default), log); preferred
  interface; send, receive and inactive colors.
- **Menu:** per interface: IP and MAC address, link speed, throughput, totals and peak. Open
  Network settings.

### App-wide

A settings window that edits `~/.config/menumeters/config.json` and launch at login.

## Left out

- The Griffin PowerMate LED driver: hardware discontinued in 2018.
- PPP status in the network menu.
- AppleScript that clicks Activity Monitor tabs; it needs the Apple Events entitlement.
- Sparkle updates: a package dependency. An update check against GitHub Releases replaces it,
  decided when it is built.
- The alert when macOS hides a meter in a crowded menu bar: it fired on false alarms
  ([0008](decisions/0008-no-hidden-meter-alert.md)).

## Efficiency

What yujitach's fork does that we keep, and what we do instead where it costs more than it needs
to. Paths are in their repo.

**Keep:**

- `host_processor_info` for CPU load and `host_statistics64` for memory.
- 20% timer tolerance, so the system can coalesce wakeups.
- The process list sampled only while the CPU menu is open; menus updated only while open.
- IOKit matching notifications for disks coming and going, rather than polling for them.
- One sysctl buffer reused across network ticks.

**Do instead:**

- **One timer for all meters,** a `DispatchSourceTimer` with leeway that ticks only meters that
  are on and due. Theirs runs four `NSTimer`s, each sampling and drawing on the main thread.
- **Check for a hidden status item on menu bar and screen changes,** not every tick. Theirs calls
  `CGWindowListCreate` per meter per tick (`MenuMetersMenuExtraBase.m`), likely its largest
  cost.
- **Skip the redraw when the drawn values haven't changed,** comparing values quantized to the
  pixel. Theirs builds a new `NSImage` every tick.
- **No allocation per tick:** fixed-size structs and ring buffers for samples and history.
  Theirs allocates objects, arrays and dictionaries per core or interface each tick.
- **64-bit network counters** from `NET_RT_IFLIST2`, so no wraparound handling. Theirs reads
  the 32-bit `NET_RT_IFLIST`.
- **Open temperature sensors once** and read them less often than load. Theirs re-matches the HID
  services (Apple silicon) or opens and closes the SMC (Intel) on every read.
- **The process list from `proc_pid_rusage`** rather than parsing `/usr/bin/top` output.
- **Appearance from `effectiveAppearance`,** not `NSUserDefaults` synchronized per check.
- **Pause sampling while the displays sleep.** Theirs keeps ticking.

## Apple silicon

- Temperature on Apple silicon has no public API; theirs uses private `IOHIDEventSystemClient`
  calls. Decide when building the temperature reading.
- Theirs treats all cores alike. Grouping performance and efficiency cores (`hw.perflevel*`) is
  an option the CPU meter can add.
- The clock-frequency and power-limit lines likely read nothing on Apple silicon; hide a line
  that has no value.
