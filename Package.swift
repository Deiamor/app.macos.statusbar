// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StatusBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StatusBar",
            path: "Sources",
            resources: [.copy("claude-icon.png")]
        )
    ]
)
