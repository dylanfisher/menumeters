/// When each meter is next due, on one clock in nanoseconds. Pure, so the scheduling rules are
/// tested without a timer; `MeterScheduler` drives it.
///
/// A meter within a fifth of its interval of being due runs with the meter that woke the timer,
/// so meters on nearby schedules share a wakeup instead of each taking one. The next due time
/// counts from when a meter ran, not from when it was due, so a late tick doesn't make the
/// following ones bunch up.
public struct TickPlan: Sendable {
    private var intervals: [UInt64] = []
    private var nextDue: [UInt64] = []

    public init() {}

    public var count: Int { intervals.count }

    /// Adds a meter, due at once. Returns its index for `forEachDue`.
    public mutating func add(intervalNanoseconds: UInt64, now: UInt64) -> Int {
        precondition(intervalNanoseconds > 0, "a meter's interval must be positive")
        intervals.append(intervalNanoseconds)
        nextDue.append(now)
        return intervals.count - 1
    }

    /// Calls `body` with the index of each meter due at `now`, and moves each one's due time an
    /// interval on from `now`.
    public mutating func forEachDue(now: UInt64, _ body: (Int) -> Void) {
        for index in intervals.indices where nextDue[index] <= now + intervals[index] / 5 {
            nextDue[index] = now + intervals[index]
            body(index)
        }
    }

    /// Makes every meter due at `now`, as after the displays wake.
    public mutating func makeAllDue(now: UInt64) {
        for index in nextDue.indices { nextDue[index] = now }
    }

    /// The earliest due time, or nil with no meters.
    public var nextDeadline: UInt64? { nextDue.min() }

    /// How late the timer may fire: a fifth of the shortest interval, the 20% tolerance yujitach
    /// gives its timers. Nil with no meters.
    public var leewayNanoseconds: UInt64? { intervals.min().map { $0 / 5 } }
}
