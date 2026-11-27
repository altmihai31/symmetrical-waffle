// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DaybookKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "DaybookKit", targets: ["DaybookKit"])
    ],
    targets: [
        .target(name: "DaybookKit"),
        .testTarget(name: "DaybookKitTests", dependencies: ["DaybookKit"])
    ]
)
