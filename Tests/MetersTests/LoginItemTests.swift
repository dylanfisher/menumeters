import Base
import Foundation
import Testing

@testable import Meters

@Test func onMacOS12TheLoginItemIsALaunchAgentFile() async throws {
    let home = FileManager.default.temporaryDirectory
        .appendingPathComponent("LoginItemTests-\(UUID().uuidString)", isDirectory: true)
    let file = AppPaths(home: home).launchAgentFile
    let executable = URL(fileURLWithPath: "/Applications/MenuMeters.app/Contents/MacOS/MenuMeters")
    let item = LoginItem(.launchAgent(file: file, executable: executable))
    #expect(await item.state() == .off)
    #expect(try await item.set(true) == .on)
    let agent = try #require(
        try PropertyListSerialization.propertyList(from: Data(contentsOf: file), format: nil)
            as? [String: Any])
    #expect(agent["Label"] as? String == bundleIdentifier)
    #expect(agent["ProgramArguments"] as? [String] == [executable.path])
    #expect(agent["RunAtLoad"] as? Bool == true)
    #expect(try await item.set(false) == .off)
    #expect(!FileManager.default.fileExists(atPath: file.path))
    #expect(try await item.set(false) == .off)
}
