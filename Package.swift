// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LiminalLacuna",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LiminalLacuna", targets: ["LiminalLacuna"])
    ],
    targets: [
        .executableTarget(
            name: "LiminalLacuna",
            path: "Sources/LiminalLacuna"
        ),
        .testTarget(
            name: "LiminalLacunaTests",
            dependencies: ["LiminalLacuna"],
            path: "Tests/LiminalLacunaTests"
        )
    ]
)
