/// When each meter is next due, on one clock in nanoseconds. Pure, so the scheduling rules are
/// tested without a timer; `MeterScheduler` drives it.
///
/// A meter within a fifth of its interval of being due runs with the meter that woke the timer,
/// so meters on nearby schedules share a wakeup instead of each taking one. The next due time
/// counts from when a meter ran, not from when it was due, so a late tick doesn't make the
/// following ones bunch up. A meter whose interval is nil is off: never due, and left out of the
/// deadline and the leeway.
public struct TickPlan: Sendable {
    private var intervals: [UInt64?] = []
    private var nextDue: [UInt64] = []

    public init() {}

    public var count: Int { intervals.count }

    /// Adds a meter, due at once unless it is off. Returns its index for `forEachDue`.
    public mutating func add(intervalNanoseconds: UInt64?, now: UInt64) -> Int {
        precondition(intervalNanoseconds != 0, "a meter's interval must be positive")
        intervals.append(intervalNanoseconds)
        nextDue.append(now)
        return intervals.count - 1
    }

    /// Changes a meter's interval, or turns it off with nil. A meter turned on is due at once; a
    /// shorter interval brings the next tick no later than one new interval from `now`, and a
    /// longer one leaves it where it was.
    public mutating func setInterval(_ index: Int, nanoseconds: UInt64?, now: UInt64) {
        precondition(nanoseconds != 0, "a meter's interval must be positive")
        if intervals[index] == nil {
            nextDue[index] = now
        } else if let nanoseconds {
            nextDue[index] = min(nextDue[index], now + nanoseconds)
        }
        intervals[index] = nanoseconds
    }

    /// Calls `body` with the index of each meter due at `now`, and moves each one's due time an
    /// interval on from `now`.
    public mutating func forEachDue(now: UInt64, _ body: (Int) -> Void) {
        for index in intervals.indices {
            guard let interval = intervals[index], nextDue[index] <= now + interval / 5 else {
                continue
            }
            nextDue[index] = now + interval
            body(index)
        }
    }

    /// Makes every meter due at `now`, as after the displays wake.
    public mutating func makeAllDue(now: UInt64) {
        for index in nextDue.indices { nextDue[index] = now }
    }

    /// The earliest due time of a meter that is on, or nil with none on.
    public var nextDeadline: UInt64? {
        intervals.indices.lazy.filter { intervals[$0] != nil }.map { nextDue[$0] }.min()
    }

    /// How late the timer may fire: a fifth of the shortest interval, the 20% tolerance yujitach
    /// gives its timers. Nil with no meter on.
    public var leewayNanoseconds: UInt64? { intervals.lazy.compactMap { $0 }.min().map { $0 / 5 } }
}
