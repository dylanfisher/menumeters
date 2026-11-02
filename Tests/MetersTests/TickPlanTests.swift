import Testing

@testable import Meters

private let second: UInt64 = 1_000_000_000

private func due(_ plan: inout TickPlan, at now: UInt64) -> [Int] {
    var indexes: [Int] = []
    plan.forEachDue(now: now) { indexes.append($0) }
    return indexes
}

@Test func aNewMeterIsDueAtOnceAndThenEveryInterval() {
    var plan = TickPlan()
    let cpu = plan.add(intervalNanoseconds: second, now: 0)
    #expect(due(&plan, at: 0) == [cpu])
    #expect(plan.nextDeadline == second)
    #expect(due(&plan, at: second / 2) == [])
    #expect(due(&plan, at: second) == [cpu])
}

@Test func aMeterNearlyDueRunsWithTheOneThatWokeTheTimer() {
    var plan = TickPlan()
    _ = plan.add(intervalNanoseconds: second, now: 0)
    _ = plan.add(intervalNanoseconds: 10 * second, now: 0)
    #expect(due(&plan, at: 0) == [0, 1])
    // The slow meter is due at 10 s; at 9 s it is within a fifth of its interval.
    #expect(due(&plan, at: 9 * second) == [0, 1])
    #expect(plan.nextDeadline == 10 * second)
}

@Test func aLateTickPushesTheNextOneBackRatherThanBunching() {
    var plan = TickPlan()
    _ = plan.add(intervalNanoseconds: second, now: 0)
    _ = due(&plan, at: 0)
    #expect(due(&plan, at: 5 * second) == [0])
    #expect(plan.nextDeadline == 6 * second)
}

@Test func makeAllDueTicksEveryMeterNext() {
    var plan = TickPlan()
    _ = plan.add(intervalNanoseconds: second, now: 0)
    _ = plan.add(intervalNanoseconds: 10 * second, now: 0)
    _ = due(&plan, at: 0)
    plan.makeAllDue(now: 3 * second)
    #expect(due(&plan, at: 3 * second) == [0, 1])
}

@Test func leewayIsAFifthOfTheShortestInterval() {
    var plan = TickPlan()
    #expect(plan.leewayNanoseconds == nil)
    _ = plan.add(intervalNanoseconds: 10 * second, now: 0)
    _ = plan.add(intervalNanoseconds: second, now: 0)
    #expect(plan.leewayNanoseconds == second / 5)
}

@Test func aMeterThatIsOffIsNeverDueAndSetsNoDeadline() {
    var plan = TickPlan()
    let cpu = plan.add(intervalNanoseconds: nil, now: 0)
    #expect(due(&plan, at: 0) == [])
    #expect(plan.nextDeadline == nil)
    #expect(plan.leewayNanoseconds == nil)
    plan.setInterval(cpu, nanoseconds: second, now: 5 * second)
    #expect(due(&plan, at: 5 * second) == [cpu])
    plan.setInterval(cpu, nanoseconds: nil, now: 6 * second)
    #expect(due(&plan, at: 100 * second) == [])
}

@Test func aShorterIntervalBringsTheNextTickCloserAndALongerOneLeavesIt() {
    var plan = TickPlan()
    let cpu = plan.add(intervalNanoseconds: 10 * second, now: 0)
    _ = due(&plan, at: 0)
    plan.setInterval(cpu, nanoseconds: 2 * second, now: 1 * second)
    #expect(plan.nextDeadline == 3 * second)
    plan.setInterval(cpu, nanoseconds: 20 * second, now: 2 * second)
    #expect(plan.nextDeadline == 3 * second)
    #expect(plan.leewayNanoseconds == 4 * second)
}
