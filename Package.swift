// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mote",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "Mote", targets: ["Mote"]),
        .executable(name: "motectl", targets: ["motectl"]),
    ],
    targets: [
        .target(
            name: "MoteCore",
            dependencies: [],
            path: "Sources/MoteCore",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "Mote",
            dependencies: ["MoteCore"],
            path: "Sources/Mote",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .executableTarget(
            name: "motectl",
            dependencies: ["MoteCore"],
            path: "Sources/motectl",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "MoteCoreTests",
            dependencies: ["MoteCore"],
            path: "Tests/MoteCoreTests"
        ),
    ]
)
