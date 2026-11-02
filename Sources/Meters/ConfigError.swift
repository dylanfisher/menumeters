/// Something wrong with the config file, or with reading, writing or watching it, in a phrase
/// that names the key when there is one: `cpu.intervalSeconds must be a number from 0.5 to 10,
/// not 30`.
public struct ConfigError: Error, Equatable, Sendable, CustomStringConvertible {
    public let reason: String

    public init(_ reason: String) {
        self.reason = reason
    }

    public var description: String { reason }
}
