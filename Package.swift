// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AeroHints",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "AeroHints",
            path: "Sources/AeroHints"
        ),
    ]
)
