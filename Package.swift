// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Summon",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Summon",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        )
    ]
)
