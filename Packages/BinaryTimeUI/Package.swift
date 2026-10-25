// swift-tools-version: 5.10
// Binary Time — AppKit / Core Animation rendering shared by the .saver and DebugHost.
// Keeps no business logic: it draws what BinaryTimeCore's ScreenModel says.
import PackageDescription

let package = Package(
    name: "BinaryTimeUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BinaryTimeUI", targets: ["BinaryTimeUI"])
    ],
    dependencies: [
        .package(path: "../BinaryTimeCore")
    ],
    targets: [
        .target(
            name: "BinaryTimeUI",
            dependencies: [.product(name: "BinaryTimeCore", package: "BinaryTimeCore")],
            path: "Sources/BinaryTimeUI"
        ),
        .testTarget(
            name: "BinaryTimeUITests",
            dependencies: ["BinaryTimeUI"],
            path: "Tests/BinaryTimeUITests"
        )
    ]
)
