// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PowerWatcher",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "PowerWatcherCore", targets: ["PowerWatcherCore"]),
        .executable(name: "PowerWatcher", targets: ["PowerWatcher"])
    ],
    targets: [
        .target(name: "PowerWatcherCore"),
        .executableTarget(name: "PowerWatcher", dependencies: ["PowerWatcherCore"]),
        .testTarget(name: "PowerWatcherCoreTests", dependencies: ["PowerWatcherCore"])
    ]
)
