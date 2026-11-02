import Base
import Foundation
import os

private let logger = moduleLogger()

/// Reads the config file off the main actor, writes the default file where there is none, and
/// reads it again after each change in its folder, so a hand edit applies while the app runs.
/// A file that doesn't parse is logged and left alone, and the app runs on the defaults until
/// it is fixed (docs/decisions/0003-config-file.md).
///
/// When the file is a symbolic link, as dotfiles often are, the folder it leads into is watched
/// too, and a write goes through the link to its target.
public actor ConfigStore {
    /// What the app should use, and what to tell the user.
    public struct State: Equatable, Sendable {
        /// The file's config; the defaults while the file has an error.
        public let config: AppConfig
        /// What is wrong with the file, or with reading, writing or watching it; nil when the
        /// file applies as it is.
        public let problem: ConfigError?
        /// Whether the file is there but sets nothing because it has an error. `save` leaves it
        /// alone then, since the user is fixing it.
        public let isFileBroken: Bool

        public init(config: AppConfig, problem: ConfigError?, isFileBroken: Bool) {
            self.config = config
            self.problem = problem
            self.isFileBroken = isFileBroken
        }
    }

    /// How long a batch of changes in the folder must be quiet before the file is read again.
    static let latencySeconds = 0.3

    public nonisolated let file: URL
    /// Each state that differs from the one before, from reads of the file and failures to
    /// write it. A good `save` sends none, since its caller already has the config it saved.
    public nonisolated let states: AsyncStream<State>
    private let feed: AsyncStream<State>.Continuation
    private var watcher: FolderWatcher?
    /// The bytes last read or written, nil for no file, so the store's own write, seen again
    /// through the watch, changes nothing.
    private var lastData: Data?
    private var published: State?

    public init(file: URL) {
        self.file = file
        (states, feed) = AsyncStream.makeStream(of: State.self)
    }

    /// Reads the file, writing the default file first where there is none, starts watching its
    /// folder, and returns the state, which `states` also gets.
    @discardableResult
    public func start() -> State {
        precondition(watcher == nil, "the config file is already watched")
        let folders = Set([
            file.deletingLastPathComponent().path, target.deletingLastPathComponent().path,
        ])
        reload()
        do {
            watcher = try FolderWatcher(
                paths: folders.sorted(), latencySeconds: Self.latencySeconds
            ) { [weak self] in
                Task { await self?.reload() }
            }
        } catch {
            fail(
                ConfigError(
                    "the config file isn't watched, so an edit applies at the next launch: \(error)"
                ))
        }
        guard let published else { preconditionFailure("the first read published nothing") }
        return published
    }

    /// Stops watching and ends `states`.
    public func stop() {
        watcher?.stop()
        watcher = nil
        feed.finish()
    }

    /// Writes `config` as the whole file, unless the file has an error.
    public func save(_ config: AppConfig) {
        if published?.isFileBroken == true {
            logger.error("not saving the config: the file has an error the user is fixing")
            return
        }
        let data = config.fileData()
        do {
            try write(data)
        } catch {
            fail(error)
            return
        }
        lastData = data
        let state = State(config: config, problem: nil, isFileBroken: false)
        // A state with the same problem as before would only echo the config back.
        if state.problem != published?.problem { feed.yield(state) }
        published = state
    }

    /// Reads the file again and publishes what changed; a missing file is replaced by the
    /// default file.
    func reload() {
        let data: Data
        do {
            guard let read = try self.read() else {
                writeDefault()
                return
            }
            data = read
        } catch {
            fail(error)
            return
        }
        guard data != lastData else { return }
        lastData = data
        do {
            publish(State(config: try AppConfig.parse(data), problem: nil, isFileBroken: false))
        } catch {
            logger.error("config file not applied: \(error.reason, privacy: .public)")
            publish(State(config: AppConfig(), problem: error, isFileBroken: true))
        }
    }

    private func writeDefault() {
        let data = AppConfig().fileData()
        do {
            try write(data)
        } catch {
            fail(error)
            return
        }
        logger.info("wrote the default config file")
        lastData = data
        publish(State(config: AppConfig(), problem: nil, isFileBroken: false))
    }

    /// Publishes a failure to read, write or watch, keeping the config in use.
    private func fail(_ error: ConfigError) {
        logger.error("\(error.reason, privacy: .public)")
        publish(
            State(
                config: published?.config ?? AppConfig(), problem: error,
                isFileBroken: published?.isFileBroken ?? false))
    }

    private func publish(_ state: State) {
        guard state != published else { return }
        published = state
        feed.yield(state)
    }

    /// The file's bytes, or nil when there is none.
    private func read() throws(ConfigError) -> Data? {
        do {
            return try Data(contentsOf: file)
        } catch CocoaError.fileReadNoSuchFile {
            return nil
        } catch {
            throw ConfigError("the config file couldn't be read: \(error.localizedDescription)")
        }
    }

    /// Writes `data` to the file atomically. Through a symbolic link, the link's target is
    /// replaced and the link stays.
    private func write(_ data: Data) throws(ConfigError) {
        let destination = target
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
        } catch {
            throw ConfigError("the config file couldn't be written: \(error.localizedDescription)")
        }
    }

    /// The file with every symbolic link in its path followed, as far as they lead.
    private var target: URL { file.resolvingSymlinksInPath() }
}
