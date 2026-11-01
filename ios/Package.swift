// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GbaEmu",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "GbaEmuCore", targets: ["GbaEmuCore"]),
        .library(name: "GbaEmuUI", targets: ["GbaEmuUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/mgba-emu/mgba", branch: "master"),
    ],
    targets: [
        .target(
            name: "GbaEmuCore",
            dependencies: [
                .product(name: "mgba", package: "mgba")
            ],
            path: "Sources/Core",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Metal"),
                .linkedFramework("MetalKit")
            ]
        ),
        .target(
            name: "GbaEmuUI",
            dependencies: ["GbaEmuCore"],
            path: "Sources/UI"
        ),
        .testTarget(
            name: "GbaEmuTests",
            dependencies: ["GbaEmuCore"],
            path: "Tests"
        )
    ]
)