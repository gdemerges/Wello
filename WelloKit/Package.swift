// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WelloKit",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "WelloKit", targets: ["WelloKit"]),
    ],
    targets: [
        .target(name: "WelloKit"),
        .testTarget(name: "WelloKitTests", dependencies: ["WelloKit"]),
    ]
)
