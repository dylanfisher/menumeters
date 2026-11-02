import Foundation
import Testing

@testable import Meters

/// A new empty folder under the temporary folder, with links followed, as FSEvents reports it.
private func temporaryFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("ConfigStoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder.resolvingSymlinksInPath()
}

private func paths() throws -> AppPaths { AppPaths(home: try temporaryFolder()) }

/// The first state from `store` that `matches`, or nil after five seconds.
private func firstState(
    of store: ConfigStore, where matches: @escaping @Sendable (ConfigStore.State) -> Bool
) async -> ConfigStore.State? {
    await withTaskGroup(of: ConfigStore.State?.self) { group in
        group.addTask {
            for await state in store.states where matches(state) { return state }
            return nil
        }
        group.addTask {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return nil
        }
        let first = await group.next() ?? nil
        group.cancelAll()
        return first
    }
}

@Test func withNoFileTheStoreWritesTheDefaults() async throws {
    let file = try paths().configFile
    let store = ConfigStore(file: file)
    let state = await store.start()
    await store.stop()
    #expect(state == .init(config: AppConfig(), problem: nil, isFileBroken: false))
    #expect(try Data(contentsOf: file) == AppConfig().fileData())
}

@Test func aFileWithAnErrorRunsOnDefaultsAndIsLeftAlone() async throws {
    let file = try paths().configFile
    let broken = Data(#"{"cpu": {"intervalSeconds": 0}}"#.utf8)
    try broken.write(to: file)
    let store = ConfigStore(file: file)
    let state = await store.start()
    var changed = AppConfig()
    changed.cpu.showsGraph = false
    await store.save(changed)
    await store.stop()
    #expect(state.config == AppConfig())
    #expect(state.isFileBroken)
    #expect(state.problem?.reason.hasPrefix("cpu.intervalSeconds must be") == true)
    #expect(try Data(contentsOf: file) == broken)
}

@Test func aSaveWritesTheFileForTheNextLaunch() async throws {
    let file = try paths().configFile
    let store = ConfigStore(file: file)
    await store.start()
    var changed = AppConfig()
    changed.cpu.graphWidthPoints = 50
    await store.save(changed)
    await store.stop()
    let next = ConfigStore(file: file)
    #expect(await next.start().config == changed)
    await next.stop()
}

@Test func aHandEditAppliesWhileTheAppRuns() async throws {
    let file = try paths().configFile
    let store = ConfigStore(file: file)
    await store.start()
    try Data(#"{"cpu": {"intervalSeconds": 5}}"#.utf8).write(to: file)
    let state = await firstState(of: store) { $0.config.cpu.intervalSeconds == 5 }
    await store.stop()
    #expect(state != nil)
    #expect(state?.problem == nil)
}

@Test func aSaveThroughALinkKeepsTheLinkAndWatchesItsTarget() async throws {
    let home = try temporaryFolder()
    let dotfiles = try temporaryFolder()
    let target = dotfiles.appendingPathComponent("menumeters.json")
    try Data("{}".utf8).write(to: target)
    let file = AppPaths(home: home).configFile
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
    let store = ConfigStore(file: file)
    await store.start()
    var changed = AppConfig()
    changed.cpu.groupsCoreKinds = false
    await store.save(changed)
    let destination = try FileManager.default.destinationOfSymbolicLink(atPath: file.path)
    #expect(destination == target.path)
    #expect(try AppConfig.parse(Data(contentsOf: target)) == changed)

    try Data(#"{"cpu": {"showsPercent": false}}"#.utf8).write(to: target)
    let state = await firstState(of: store) { !$0.config.cpu.showsPercent }
    await store.stop()
    #expect(state != nil)
}
