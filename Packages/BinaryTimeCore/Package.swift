// swift-tools-version: 5.10
// Binary Time — Core package. Pure Swift + Foundation (+ SystemConfiguration for the
// local VPN check). No AppKit: everything here is unit-testable with `swift test`.
import PackageDescription

let package = Package(
    name: "BinaryTimeCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BinaryTimeCore", targets: ["BinaryTimeCore"])
    ],
    targets: [
        .target(
            name: "BinaryTimeCore",
            path: "Sources/BinaryTimeCore",
            linkerSettings: [.linkedFramework("SystemConfiguration")]
        ),
        .testTarget(
            name: "BinaryTimeCoreTests",
            dependencies: ["BinaryTimeCore"],
            path: "Tests/BinaryTimeCoreTests"
        )
    ]
)
