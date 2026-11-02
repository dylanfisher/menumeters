/// The CPU meter's settings. Defaults follow yujitach's, except that both the percentage and
/// the graph start on. Read from the config file once that exists; until then, the defaults.
public struct CPUConfig: Sendable, Equatable {
    public var intervalSeconds: Double = 1
    public var showsPercent = true
    public var showsGraph = true
    /// One column per sample, so this is also how many samples the graph shows.
    public var graphWidthPoints = 33
    /// On a Mac with performance and efficiency cores, show each kind as its own row: the top
    /// row performance, the bottom efficiency. Off, or on a Mac with one kind, one row averages
    /// every core.
    public var groupsCoreKinds = true

    public init() {}

    public static let intervalSecondsRange = 0.5...10.0
    public static let graphWidthPointsRange = 11...88
}
