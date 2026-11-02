import Base
import Foundation
import os

private let logger = moduleLogger()

/// Lists the mounted volumes and ejects them, off the main thread: both reach the file system,
/// and a slow network share or a spun-down disk can take seconds to answer.
public actor VolumeStore {
    /// Why a volume couldn't be ejected, in a phrase for an alert.
    public struct EjectFailed: Error, Sendable, CustomStringConvertible {
        public let reason: String
        public var description: String { reason }
    }

    private static let keys: [URLResourceKey] = [
        .volumeLocalizedNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey, .volumeIsEjectableKey,
        .volumeIsRemovableKey, .volumeIsLocalKey,
    ]

    public init() {}

    /// The volumes Finder shows, the startup volume first, in name order after it. A volume
    /// that can't say what it holds is left out and logged.
    public func volumes() -> [Volume] {
        guard
            let urls = FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: Self.keys, options: [.skipHiddenVolumes])
        else { return [] }
        var volumes: [Volume] = []
        for url in urls {
            let values: URLResourceValues
            do {
                values = try url.resourceValues(forKeys: Set(Self.keys))
            } catch {
                logger.error("volume skipped: \(error.localizedDescription)")
                continue
            }
            let available =
                values.volumeAvailableCapacityForImportantUsage
                ?? values.volumeAvailableCapacity.map(Int64.init) ?? 0
            volumes.append(
                Volume(
                    url: url, name: values.volumeLocalizedName ?? url.lastPathComponent,
                    totalBytes: Int64(values.volumeTotalCapacity ?? 0), availableBytes: available,
                    isEjectable: values.volumeIsEjectable == true
                        || values.volumeIsRemovable == true
                        || values.volumeIsLocal == false))
        }
        return volumes.sorted {
            ($0.url.path == "/" ? 0 : 1, $0.name) < ($1.url.path == "/" ? 0 : 1, $1.name)
        }
    }

    /// Unmounts `volume` and ejects its disk, with every other volume on that disk.
    public func eject(_ volume: Volume) async throws(EjectFailed) {
        do {
            try await FileManager.default.unmountVolume(
                at: volume.url, options: [.allPartitionsAndEjectDisk])
        } catch {
            throw EjectFailed(reason: error.localizedDescription)
        }
    }
}
