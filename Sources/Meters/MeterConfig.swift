/// What every meter's section of the config file has: an on/off switch and an interval.
public protocol MeterConfig {
    var isEnabled: Bool { get }
    var intervalSeconds: Double { get }
}

extension MeterConfig {
    /// The interval for `MeterScheduler`: nil while the meter is off.
    public var scheduledIntervalSeconds: Double? { isEnabled ? intervalSeconds : nil }
}

extension CPUConfig: MeterConfig {}
extension MemoryConfig: MeterConfig {}
extension NetworkConfig: MeterConfig {}
