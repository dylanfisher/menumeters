import Foundation

/// Everything the config file sets: one section per meter. The file is strict JSON; a key or a
/// whole section left out keeps its default, and a file with any error sets nothing
/// (docs/decisions/0003-config-file.md).
public struct AppConfig: Sendable, Equatable, Codable {
    public var cpu = CPUConfig()

    public init() {}

    enum Key: String, CodingKey, CaseIterable {
        case cpu
    }

    public init(from decoder: any Decoder) throws {
        let section = try ConfigSection<Key>(decoder)
        cpu = try section.section(.cpu, default: cpu)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        try container.encode(cpu, forKey: .cpu)
    }

    /// The config `data` sets, or what is wrong with it.
    public static func parse(_ data: Data) throws(ConfigError) -> AppConfig {
        guard !data.allSatisfy({ [0x20, 0x09, 0x0A, 0x0D].contains($0) }) else {
            throw ConfigError("the file is empty: it needs a JSON object, such as {}")
        }
        do {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch let error as ConfigError {
            throw error
        } catch DecodingError.dataCorrupted(let context) {
            let detail =
                (context.underlyingError as? NSError)?
                .userInfo[NSDebugDescriptionErrorKey] as? String
            throw ConfigError("the file isn't valid JSON" + (detail.map { ": \($0)" } ?? ""))
        } catch {
            throw ConfigError("the file couldn't be read as JSON: \(error)")
        }
    }

    /// The file's text for this config: every key, sorted, two spaces to a level.
    public func fileData() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            return try encoder.encode(self) + Data("\n".utf8)
        } catch {
            preconditionFailure("the config didn't encode: \(error)")
        }
    }
}
