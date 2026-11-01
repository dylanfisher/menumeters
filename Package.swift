// swift-tools-version: 6.2

import PackageDescription

// Each tier is a target, so this file is the tier map: a target may depend only on the tiers
// below it (docs/map.md). The build rejects an import of a target that isn't listed here.
let strictSwift: [SwiftSetting] = [.treatAllWarnings(as: .error)]

let package = Package(
    name: "MenuMeters",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "MenuMeters", targets: ["App"])
    ],
    targets: [
        .target(name: "Base", swiftSettings: strictSwift),
        .target(name: "Meters", dependencies: ["Base"], swiftSettings: strictSwift),
        .target(name: "Interface", dependencies: ["Meters", "Base"], swiftSettings: strictSwift),
        .executableTarget(
            name: "App",
            dependencies: ["Interface", "Meters", "Base"],
            exclude: ["Info.plist"],
            swiftSettings: strictSwift
        ),
        .testTarget(name: "BaseTests", dependencies: ["Base"], swiftSettings: strictSwift),
        .testTarget(
            name: "MetersTests", dependencies: ["Meters", "Base"], swiftSettings: strictSwift),
        .testTarget(
            name: "InterfaceTests", dependencies: ["Interface", "Meters", "Base"],
            swiftSettings: strictSwift),
    ],
    swiftLanguageModes: [.v6]
)
