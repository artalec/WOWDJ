// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DJPlayer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DJPlayer",
            targets: ["DJPlayer"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DJPlayer",
            dependencies: [],
            path: "Sources"
        )
    ]
)
