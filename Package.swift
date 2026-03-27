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
            exclude: ["Info.plist"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/Mote/Info.plist",
                ]),
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
