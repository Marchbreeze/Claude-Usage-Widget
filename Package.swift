// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "UsageCore"),
        .executableTarget(name: "ClaudeUsageWidget", dependencies: ["UsageCore"]),
        .testTarget(
            name: "UsageCoreTests",
            dependencies: ["UsageCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
