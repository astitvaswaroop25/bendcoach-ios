// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BendKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "BendKit", targets: ["BendKit"])
    ],
    targets: [
        .target(name: "BendKit"),
        .testTarget(name: "BendKitTests", dependencies: ["BendKit"])
    ]
)
