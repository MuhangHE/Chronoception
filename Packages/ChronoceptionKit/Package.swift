// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChronoceptionKit",
    platforms: [
        .iOS("26.0"),
        .watchOS("26.0"),
        .macOS(.v15), // 让 `swift test` 直接在 Mac 上跑
    ],
    products: [
        .library(name: "ChronoceptionKit", targets: ["ChronoceptionKit"]),
    ],
    targets: [
        .target(name: "ChronoceptionKit"),
        .testTarget(name: "ChronoceptionKitTests", dependencies: ["ChronoceptionKit"]),
    ]
)
