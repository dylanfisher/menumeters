import Foundation
import IOKit

/// Reads disk activity from the statistics every `IOBlockStorageDriver` keeps, as yujitach's
/// fork does. The drivers come from IOKit matching notifications on the main queue, so a disk
/// coming or going is noticed without polling for it.
///
/// A sample reads one statistics dictionary per disk. IOKit allocates each one as a CF object,
/// which no IOKit call avoids; nothing is allocated on the Swift heap.
///
/// Not thread-safe; the disk meter owns one and samples it on the main actor.
public final class DiskActivitySampler {
    /// The drivers matched so far, each retained until it terminates.
    private var drivers: [io_service_t] = []
    private let port: IONotificationPortRef
    private var notifications: [io_iterator_t] = []
    private var totals = DiskTotals.zero

    /// The activity between the last two calls to `sample()`.
    public private(set) var activity = DiskActivity.idle

    // Made once rather than per sample; CF strings aren't Sendable, so they can't be static.
    private let statisticsKey = "Statistics" as CFString
    private let readKey = "Bytes (Read)" as CFString
    private let writtenKey = "Bytes (Write)" as CFString

    public init() {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            preconditionFailure("IONotificationPortCreate failed")
        }
        self.port = port
        IONotificationPortSetDispatchQueue(port, .main)
        watch(kIOFirstMatchNotification) { sampler, iterator in sampler.add(iterator) }
        watch(kIOTerminatedNotification) { sampler, iterator in sampler.remove(iterator) }
        totals = readTotals()
    }

    deinit {
        for notification in notifications { IOObjectRelease(notification) }
        for driver in drivers { IOObjectRelease(driver) }
        IONotificationPortDestroy(port)
    }

    /// How many disks are watched.
    public var diskCount: Int { drivers.count }

    public func sample() {
        let current = readTotals()
        activity = DiskActivity(previous: totals, current: current)
        totals = current
    }

    private func readTotals() -> DiskTotals {
        var totals = DiskTotals.zero
        for driver in drivers {
            guard
                let property = IORegistryEntryCreateCFProperty(
                    driver, statisticsKey, kCFAllocatorDefault, 0)?.takeRetainedValue(),
                CFGetTypeID(property) == CFDictionaryGetTypeID()
            else { continue }
            let statistics = property as! CFDictionary
            totals.readBytes &+= Self.number(statistics, readKey)
            totals.writtenBytes &+= Self.number(statistics, writtenKey)
        }
        return totals
    }

    private static func number(_ dictionary: CFDictionary, _ key: CFString) -> UInt64 {
        guard let value = CFDictionaryGetValue(dictionary, Unmanaged.passUnretained(key).toOpaque())
        else { return 0 }
        let number = unsafeBitCast(value, to: CFNumber.self)
        var result: Int64 = 0
        CFNumberGetValue(number, .sInt64Type, &result)
        return UInt64(max(result, 0))
    }

    /// Arms a matching notification for block storage drivers and takes the ones already there.
    private func watch(
        _ type: String, _ handle: @escaping (DiskActivitySampler, io_iterator_t) -> Void
    ) {
        let box = Unmanaged.passRetained(Handler(sampler: self, handle: handle))
        var iterator: io_iterator_t = IO_OBJECT_NULL
        let result = IOServiceAddMatchingNotification(
            port, type, IOServiceMatching("IOBlockStorageDriver"),
            { context, iterator in
                guard let context else { return }
                let handler = Unmanaged<Handler>.fromOpaque(context).takeUnretainedValue()
                guard let sampler = handler.sampler else { return }
                handler.handle(sampler, iterator)
            }, box.toOpaque(), &iterator)
        precondition(result == KERN_SUCCESS, "IOServiceAddMatchingNotification failed: \(result)")
        notifications.append(iterator)
        // The notification is armed only once its iterator has been run through.
        handle(self, iterator)
    }

    private func add(_ iterator: io_iterator_t) {
        while case let driver = IOIteratorNext(iterator), driver != IO_OBJECT_NULL {
            drivers.append(driver)
        }
        // A new disk's totals since it appeared would read as activity.
        totals = readTotals()
    }

    private func remove(_ iterator: io_iterator_t) {
        while case let driver = IOIteratorNext(iterator), driver != IO_OBJECT_NULL {
            drivers.removeAll { IOObjectIsEqualTo($0, driver) != 0 }
            IOObjectRelease(driver)
        }
        totals = readTotals()
    }

    /// What a notification's C callback reaches through its context pointer. Kept for the life
    /// of the process: IOKit has no way to stop a notification's callback short of releasing
    /// its port.
    private final class Handler {
        weak var sampler: DiskActivitySampler?
        let handle: (DiskActivitySampler, io_iterator_t) -> Void

        init(
            sampler: DiskActivitySampler,
            handle: @escaping (DiskActivitySampler, io_iterator_t) -> Void
        ) {
            self.sampler = sampler
            self.handle = handle
        }
    }
}
