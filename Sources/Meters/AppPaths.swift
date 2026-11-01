import Base
import Foundation

/// Where the app keeps its files: the config file the user edits, and the folder of the files
/// the app writes for itself. Every path the app reads or writes is built from one of these, so
/// tests and runs that must not touch the real files pass their own.
public struct AppPaths: Sendable {
    public var configFile: URL
    public var dataDirectory: URL

    public static let configFileName = "config.json"

    public init(configFile: URL, dataDirectory: URL) {
        self.configFile = configFile
        self.dataDirectory = dataDirectory
    }

    /// Everything in one folder, for tests and runs that must not touch the real files.
    public init(home: URL) {
        self.init(
            configFile: home.appendingPathComponent(Self.configFileName, isDirectory: false),
            dataDirectory: home)
    }

    /// `~/.config/menumeters/config.json` and `~/Library/Application Support/MenuMeters`.
    /// The config file sits under `~/.config` so it can be versioned and copied with other
    /// dotfiles. Built with the URL APIs of macOS 12; `URL.homeDirectory` and friends need 13.
    public static var standard: AppPaths {
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        guard
            let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
                .first
        else {
            preconditionFailure("the user domain has no Application Support folder")
        }
        return AppPaths(
            configFile: home.appendingPathComponent(
                ".config/menumeters/\(configFileName)", isDirectory: false),
            dataDirectory: support.appendingPathComponent(appDirectoryName, isDirectory: true))
    }
}
