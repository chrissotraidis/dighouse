// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Dighouse",
    platforms: [.macOS(.v14)],
    targets: [.executableTarget(name: "Dighouse", path: "Sources/Dighouse")]
)
