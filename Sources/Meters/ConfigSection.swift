import Foundation

/// One JSON object of the config file, as a config's `init(from:)` reads it. Each key may be left
/// out for its default; a key the object can't have, or a value its key can't take, is a
/// `ConfigError` that names the key by its path, such as `cpu.intervalSeconds`.
struct ConfigSection<Key: CodingKey & CaseIterable> {
    private let container: KeyedDecodingContainer<Key>
    private let path: [String]

    init(_ decoder: any Decoder) throws(ConfigError) {
        path = decoder.codingPath.map(\.stringValue)
        do {
            let present = try decoder.container(keyedBy: AnyKey.self)
            if let unknown = present.allKeys.first(where: {
                Key(stringValue: $0.stringValue) == nil
            }) {
                throw ConfigError("unknown key \(Self.name(path + [unknown.stringValue]))")
            }
            container = try decoder.container(keyedBy: Key.self)
        } catch let error as ConfigError {
            throw error
        } catch {
            let what = path.isEmpty ? "the file" : Self.name(path)
            throw ConfigError("\(what) must be a JSON object, its keys and values in braces")
        }
    }

    func bool(_ key: Key, default value: Bool) throws(ConfigError) -> Bool {
        try decode(key, as: Bool.self, "true or false") ?? value
    }

    func double(_ key: Key, default value: Double, in range: ClosedRange<Double>)
        throws(ConfigError) -> Double
    {
        let kind = "a number from \(Self.text(range.lowerBound)) to \(Self.text(range.upperBound))"
        guard let read = try decode(key, as: Double.self, kind) else { return value }
        guard range.contains(read) else { throw invalid(key, kind, not: Self.text(read)) }
        return read
    }

    func int(_ key: Key, default value: Int, in range: ClosedRange<Int>) throws(ConfigError) -> Int
    {
        let kind = "a whole number from \(range.lowerBound) to \(range.upperBound)"
        guard let read = try decode(key, as: Int.self, kind) else { return value }
        guard range.contains(read) else { throw invalid(key, kind, not: String(read)) }
        return read
    }

    /// A nested section, read by its type's own `init(from:)`.
    func section<T: Decodable>(_ key: Key, default value: T) throws(ConfigError) -> T {
        do {
            return try container.decodeIfPresent(T.self, forKey: key) ?? value
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError("\(name(key)) must be a JSON object, its keys and values in braces")
        }
    }

    /// The full name of `key`, for an error about more than one key.
    func name(_ key: Key) -> String { Self.name(path + [key.stringValue]) }

    private func decode<T: Decodable>(_ key: Key, as type: T.Type, _ kind: String)
        throws(ConfigError) -> T?
    {
        do {
            return try container.decodeIfPresent(type, forKey: key)
        } catch {
            throw ConfigError("\(name(key)) must be \(kind)")
        }
    }

    private func invalid(_ key: Key, _ kind: String, not value: String) -> ConfigError {
        ConfigError("\(name(key)) must be \(kind), not \(value)")
    }

    private static func name(_ path: [String]) -> String { path.joined(separator: ".") }

    /// `2` rather than `2.0`, as the file would spell it.
    private static func text(_ value: Double) -> String { String(format: "%g", value) }

    private struct AnyKey: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }
}
