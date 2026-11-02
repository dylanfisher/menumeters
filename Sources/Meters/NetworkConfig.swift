/// The network meter's settings, the `network` section of the config file. The interval default
/// and range, and arrows alone by default, are yujitach's.
public struct NetworkConfig: Sendable, Equatable, Codable {
    public var isEnabled = true
    public var intervalSeconds: Double = 2
    /// At least one of the arrows and the throughput is on; the file can't turn off both.
    public var showsArrows = true
    public var showsThroughput = false

    public init() {}

    public static let intervalSecondsRange = 0.5...20.0

    enum Key: String, CodingKey, CaseIterable {
        case isEnabled = "enabled"
        case intervalSeconds, showsArrows, showsThroughput
    }

    public init(from decoder: any Decoder) throws {
        let section = try ConfigSection<Key>(decoder)
        isEnabled = try section.bool(.isEnabled, default: isEnabled)
        intervalSeconds = try section.double(
            .intervalSeconds, default: intervalSeconds, in: Self.intervalSecondsRange)
        showsArrows = try section.bool(.showsArrows, default: showsArrows)
        showsThroughput = try section.bool(.showsThroughput, default: showsThroughput)
        guard showsArrows || showsThroughput else {
            throw ConfigError(
                "\(section.name(.showsArrows)) and \(section.name(.showsThroughput)) can't both "
                    + "be false; set \(section.name(.isEnabled)) to false to hide the meter")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(intervalSeconds, forKey: .intervalSeconds)
        try container.encode(showsArrows, forKey: .showsArrows)
        try container.encode(showsThroughput, forKey: .showsThroughput)
    }
}
