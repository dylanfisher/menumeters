/// The CPU meter's settings, the `cpu` section of the config file. Defaults follow yujitach's,
/// except that both the percentage and the graph start on, and the interval is 2 s rather than
/// 1 s: each redraw costs about 11 ms on macOS 27
/// (docs/decisions/0002-draw-meters-as-button-subviews.md).
public struct CPUConfig: Sendable, Equatable, Codable {
    public var isEnabled = true
    public var intervalSeconds: Double = 2
    /// At least one of the percentage and the graph is on; the file can't turn off both.
    public var showsPercent = true
    public var showsGraph = true
    /// One column per sample, so this is also how many samples the graph shows.
    public var graphWidthPoints = 33
    /// On a Mac with more than one kind of core, show each kind as its own row, the fastest on
    /// top. Off, or on a Mac with one kind, one row averages every core.
    public var groupsCoreKinds = true

    public init() {}

    public static let intervalSecondsRange = 0.5...10.0
    public static let graphWidthPointsRange = 11...88

    enum Key: String, CodingKey, CaseIterable {
        case isEnabled = "enabled"
        case intervalSeconds, showsPercent, showsGraph, graphWidthPoints, groupsCoreKinds
    }

    public init(from decoder: any Decoder) throws {
        let section = try ConfigSection<Key>(decoder)
        isEnabled = try section.bool(.isEnabled, default: isEnabled)
        intervalSeconds = try section.double(
            .intervalSeconds, default: intervalSeconds, in: Self.intervalSecondsRange)
        showsPercent = try section.bool(.showsPercent, default: showsPercent)
        showsGraph = try section.bool(.showsGraph, default: showsGraph)
        graphWidthPoints = try section.int(
            .graphWidthPoints, default: graphWidthPoints, in: Self.graphWidthPointsRange)
        groupsCoreKinds = try section.bool(.groupsCoreKinds, default: groupsCoreKinds)
        guard showsPercent || showsGraph else {
            throw ConfigError(
                "\(section.name(.showsPercent)) and \(section.name(.showsGraph)) can't both be "
                    + "false; set \(section.name(.isEnabled)) to false to hide the meter")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(intervalSeconds, forKey: .intervalSeconds)
        try container.encode(showsPercent, forKey: .showsPercent)
        try container.encode(showsGraph, forKey: .showsGraph)
        try container.encode(graphWidthPoints, forKey: .graphWidthPoints)
        try container.encode(groupsCoreKinds, forKey: .groupsCoreKinds)
    }
}
