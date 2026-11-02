import Darwin

/// Facts about the Mac for the CPU menu, read when the menu opens rather than on the tick.
public enum SystemStatus {
    /// The marketing name, such as "Apple M1 Max" or "Intel(R) Core(TM) i7-4980HQ CPU @ 2.80GHz".
    public static var processorName: String {
        guard let name = Sysctl.string("machdep.cpu.brand_string") else {
            preconditionFailure("sysctl machdep.cpu.brand_string is missing")
        }
        return name
    }

    /// Seconds since boot, including time asleep, as `uptime` counts it.
    public static func uptimeSeconds(now: timeval = currentTime()) -> Int {
        guard let boot = Sysctl.value("kern.boottime", as: timeval.self, zero: timeval()) else {
            preconditionFailure("sysctl kern.boottime is missing")
        }
        return now.tv_sec - boot.tv_sec
    }

    /// The 1, 5 and 15 minute load averages.
    public static var loadAverages: (Double, Double, Double) {
        var values = [0.0, 0.0, 0.0]
        let count = getloadavg(&values, 3)
        precondition(count == 3, "getloadavg returned \(count) values")
        return (values[0], values[1], values[2])
    }

    public static func currentTime() -> timeval {
        var now = timeval()
        gettimeofday(&now, nil)
        return now
    }
}
