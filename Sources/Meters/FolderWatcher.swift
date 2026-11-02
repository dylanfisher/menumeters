import CoreServices
import Foundation

/// Calls back after each batch of changes in or under some folders, through one FSEvents
/// stream. FSEvents matches each change by its path, so a folder that doesn't exist yet is
/// watched too, and a file replaced by an atomic save, which a watch of the file itself would
/// lose, is a change in its folder. Taken from simple-spotlight's `FolderWatcher`.
final class FolderWatcher: @unchecked Sendable {
    /// What the C callback reaches through its context pointer. `stopped` is guarded by `lock`.
    private final class Receiver: @unchecked Sendable {
        let onChange: @Sendable () -> Void
        let lock = NSLock()
        var stopped = false

        init(onChange: @escaping @Sendable () -> Void) {
            self.onChange = onChange
        }

        func deliver() {
            lock.lock()
            let live = !stopped
            lock.unlock()
            if live { onChange() }
        }
    }

    /// The system wouldn't start the stream; FSEvents gives no reason.
    struct StartFailed: Error, CustomStringConvertible {
        let paths: [String]

        var description: String { "FSEvents wouldn't watch \(paths.joined(separator: ", "))" }
    }

    private let stream: FSEventStreamRef
    private let receiver: Receiver
    /// Guards `stopped`.
    private let lock = NSLock()
    private var stopped = false

    /// Starts watching `paths`, calling `onChange` on a serial queue once a batch of changes has
    /// been quiet for `latencySeconds`. The wait lets an editor's save in place, which empties
    /// the file before writing it, finish before the file is read.
    init(paths: [String], latencySeconds: Double, onChange: @escaping @Sendable () -> Void)
        throws(StartFailed)
    {
        let receiver = Receiver(onChange: onChange)
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passRetained(receiver).toOpaque(),
            retain: nil, release: { Unmanaged<Receiver>.fromOpaque($0!).release() },
            copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            Unmanaged<Receiver>.fromOpaque(info!).takeUnretainedValue().deliver()
        }
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot)
        guard
            let stream = FSEventStreamCreate(
                nil, callback, &context, paths as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latencySeconds, flags)
        else {
            // Creating the stream failed before it took ownership of the receiver.
            Unmanaged.passUnretained(receiver).release()
            throw StartFailed(paths: paths)
        }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue(label: "FolderWatcher"))
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            throw StartFailed(paths: paths)
        }
        self.stream = stream
        self.receiver = receiver
    }

    /// Stops the stream. A callback already running may finish, and none starts after.
    func stop() {
        lock.lock()
        defer { lock.unlock() }
        if stopped { return }
        stopped = true
        receiver.lock.lock()
        receiver.stopped = true
        receiver.lock.unlock()
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
    }

    deinit { stop() }
}
