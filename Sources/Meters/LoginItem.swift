import Base
import Foundation
import ServiceManagement

/// Whether the app opens at login. macOS 13 and later keep that in `SMAppService`; macOS 12 has
/// no API for an app outside the App Store, so there it is a LaunchAgent the app writes. Both
/// touch the file system, so they run off the main thread.
public actor LoginItem {
    public enum State: Sendable, Equatable {
        case off
        case on
        /// Registered, but waiting for the user to allow it in System Settings, Login Items.
        case needsApproval
    }

    /// Why the setting couldn't be changed, in a phrase for the settings window.
    public struct Failure: Error, Sendable, Equatable, CustomStringConvertible {
        public let reason: String

        public init(reason: String) {
            self.reason = reason
        }

        public var description: String { reason }
    }

    /// How the setting is kept.
    public enum Mechanism: Sendable {
        /// A LaunchAgent at `file` that runs `executable`.
        case launchAgent(file: URL, executable: URL)
        /// `SMAppService.mainApp`, macOS 13 and later.
        case serviceManagement
    }

    private let mechanism: Mechanism

    public init(_ mechanism: Mechanism) {
        self.mechanism = mechanism
    }

    /// `SMAppService` where the system has it, otherwise a LaunchAgent at the path in `paths`
    /// for `executable`.
    public static func standard(paths: AppPaths, executable: URL) -> LoginItem {
        if #available(macOS 13, *) { return LoginItem(.serviceManagement) }
        return LoginItem(.launchAgent(file: paths.launchAgentFile, executable: executable))
    }

    public func state() -> State {
        switch mechanism {
        case .launchAgent(let file, _):
            return FileManager.default.fileExists(atPath: file.path) ? .on : .off
        case .serviceManagement:
            guard #available(macOS 13, *) else {
                preconditionFailure("SMAppService needs macOS 13")
            }
            switch SMAppService.mainApp.status {
            case .enabled: return .on
            case .requiresApproval: return .needsApproval
            default: return .off
            }
        }
    }

    /// Turns opening at login on or off, and returns the state that follows.
    public func set(_ isOn: Bool) throws(Failure) -> State {
        do {
            switch mechanism {
            case .launchAgent(let file, let executable):
                if isOn {
                    try FileManager.default.createDirectory(
                        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try Self.launchAgent(executable: executable).write(to: file, options: .atomic)
                } else if FileManager.default.fileExists(atPath: file.path) {
                    try FileManager.default.removeItem(at: file)
                }
            case .serviceManagement:
                guard #available(macOS 13, *) else {
                    preconditionFailure("SMAppService needs macOS 13")
                }
                if isOn {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            throw Failure(
                reason: "Opening at login couldn't be changed: \(error.localizedDescription)")
        }
        return state()
    }

    /// A LaunchAgent that runs `executable` once at login, in the user's graphical session.
    static func launchAgent(executable: URL) throws -> Data {
        let agent: [String: Any] = [
            "Label": bundleIdentifier,
            "ProgramArguments": [executable.path],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "LimitLoadToSessionType": "Aqua",
        ]
        return try PropertyListSerialization.data(fromPropertyList: agent, format: .xml, options: 0)
    }
}
