import Base
import Foundation

/// Where the app keeps its files: the config file the user edits, the folder of the files the
/// app writes for itself, and the LaunchAgent that opens it at login on macOS 12. Every path the app reads or writes is built from one of these, so
/// tests and runs that must not touch the real files pass their own.
public struct AppPaths: Sendable {
    public var configFile: URL
    public var dataDirectory: URL
    public var launchAgentFile: URL

    public static let configFileName = "config.json"
    public static let launchAgentFileName = "\(bundleIdentifier).plist"

    public init(configFile: URL, dataDirectory: URL, launchAgentFile: URL) {
        self.configFile = configFile
        self.dataDirectory = dataDirectory
        self.launchAgentFile = launchAgentFile
    }

    /// Everything in one folder, for tests and runs that must not touch the real files.
    public init(home: URL) {
        self.init(
            configFile: home.appendingPathComponent(Self.configFileName, isDirectory: false),
            dataDirectory: home,
            launchAgentFile: home.appendingPathComponent(
                "LaunchAgents/\(Self.launchAgentFileName)", isDirectory: false))
    }

    /// `~/.config/menumeters/config.json`, `~/Library/Application Support/MenuMeters` and
    /// `~/Library/LaunchAgents/com.dylanfisher.MenuMeters.plist`.
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
            dataDirectory: support.appendingPathComponent(appDirectoryName, isDirectory: true),
            launchAgentFile: home.appendingPathComponent(
                "Library/LaunchAgents/\(launchAgentFileName)", isDirectory: false))
    }
}
