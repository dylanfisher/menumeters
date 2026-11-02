/// The disk meter's settings, the `disk` section of the config file. The interval default and
/// range are yujitach's.
public struct DiskConfig: Sendable, Equatable, Codable {
    public var isEnabled = true
    public var intervalSeconds = 0.3

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
