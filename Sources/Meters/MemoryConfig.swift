/// The memory meter's settings, the `memory` section of the config file. The interval default
/// and range are yujitach's.
public struct MemoryConfig: Sendable, Equatable, Codable {
    /// How the meter shows memory in the menu bar.
    public enum Display: String, Sendable, CaseIterable {
        /// A pie of wired, active, compressed and inactive memory; the rest is free.
        case pie
        /// Used and free memory as two lines of numbers.
        case number
    }

    public var isEnabled = true
    public var intervalSeconds: Double = 10
    public var display = Display.pie

    public init() {}

    public static let intervalSecondsRange = 1.0...60.0

    enum Key: String, CodingKey, CaseIterable {
        case isEnabled = "enabled"
        case intervalSeconds, display
    }

    public init(from decoder: any Decoder) throws {
        let section = try ConfigSection<Key>(decoder)
        isEnabled = try section.bool(.isEnabled, default: isEnabled)
        intervalSeconds = try section.double(
            .intervalSeconds, default: intervalSeconds, in: Self.intervalSecondsRange)
        display = try section.choice(.display, default: display)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(intervalSeconds, forKey: .intervalSeconds)
        try container.encode(display.rawValue, forKey: .display)
    }
}
