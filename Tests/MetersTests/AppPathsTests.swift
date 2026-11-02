import Base
import Foundation
import Testing

@testable import Meters

@Test func aHomeRootsEveryPathInOneFolder() {
    let home = URL(fileURLWithPath: "/tmp/app-paths-test", isDirectory: true)
    let paths = AppPaths(home: home)
    #expect(paths.configFile.path == "/tmp/app-paths-test/config.json")
    #expect(paths.dataDirectory.path == home.path)
    #expect(
        paths.launchAgentFile.path
            == "/tmp/app-paths-test/LaunchAgents/com.dylanfisher.MenuMeters.plist")
}

@Test func theStandardPathsAreUnderTheUsersHome() {
    let paths = AppPaths.standard
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    #expect(paths.configFile.path.hasPrefix(home + "/.config/menumeters/"))
    #expect(paths.configFile.lastPathComponent == AppPaths.configFileName)
    #expect(paths.dataDirectory.lastPathComponent == appDirectoryName)
    #expect(paths.launchAgentFile.path == home + "/Library/LaunchAgents/\(bundleIdentifier).plist")
}
