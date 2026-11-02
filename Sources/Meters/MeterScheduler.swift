import Dispatch

/// A meter the scheduler ticks.
@MainActor
public protocol ScheduledMeter: AnyObject {
    /// Samples and, when what it shows has changed, redraws. Runs on the main actor.
    func tick()
}

/// One timer for every meter. It fires when the earliest meter is due, ticks every meter that is
/// due by then (see `TickPlan`), and sets itself for the next. Yujitach's fork runs a timer per
/// meter.
///
/// The timer runs on the main queue so a tick can draw without a hop between threads; sampling a
/// meter takes microseconds.
@MainActor
public final class MeterScheduler {
    private var plan = TickPlan()
    private var meters: [any ScheduledMeter] = []
    private let timer = DispatchSource.makeTimerSource(queue: .main)
    private var isPaused = false

    public init() {
        timer.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.fire() }
        }
        timer.schedule(deadline: .distantFuture)
        timer.activate()
    }

    /// Adds `meter`, ticking it now and then every `intervalSeconds`.
    public func add(_ meter: any ScheduledMeter, intervalSeconds: Double) {
        precondition(intervalSeconds > 0, "a meter's interval must be positive")
        _ = plan.add(intervalNanoseconds: UInt64(intervalSeconds * 1e9), now: Self.now())
        meters.append(meter)
        if !isPaused { fire() }
    }

    /// Stops ticking, as while the displays sleep.
    public func pause() {
        isPaused = true
        timer.schedule(deadline: .distantFuture)
    }

    /// Ticks every meter now and resumes the schedule.
    public func resume() {
        guard isPaused else { return }
        isPaused = false
        plan.makeAllDue(now: Self.now())
        fire()
    }

    private func fire() {
        guard !isPaused else { return }
        let now = Self.now()
        plan.forEachDue(now: now) { meters[$0].tick() }
        guard let deadline = plan.nextDeadline, let leeway = plan.leewayNanoseconds else {
            return
        }
        timer.schedule(
            deadline: DispatchTime(uptimeNanoseconds: max(deadline, now + 1)),
            leeway: .nanoseconds(Int(leeway)))
    }

    /// The clock `DispatchTime` uses, which stops while the Mac sleeps.
    private static func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
}
