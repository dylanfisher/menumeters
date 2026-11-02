/// The disk meter's settings, the `disk` section of the config file. The interval range is
/// yujitach's; the default is 1 s rather than their 0.3 s, since each change of the light costs a
/// status item redraw (docs/decisions/0005-disk-interval-1-s.md).
public struct DiskConfig: Sendable, Equatable, Codable {
    public var isEnabled = true
    public var intervalSeconds = 1.0

    public init() {}

    public static let intervalSecondsRange = 0.1...5.0

    enum Key: String, CodingKey, CaseIterable {
        case isEnabled = "enabled"
        case intervalSeconds
    }

    public init(from decoder: any Decoder) throws {
        let section = try ConfigSection<Key>(decoder)
        isEnabled = try section.bool(.isEnabled, default: isEnabled)
        intervalSeconds = try section.double(
            .intervalSeconds, default: intervalSeconds, in: Self.intervalSecondsRange)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(intervalSeconds, forKey: .intervalSeconds)
    }
}
