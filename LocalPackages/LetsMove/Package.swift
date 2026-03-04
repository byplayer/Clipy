// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "LetsMove",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LetsMove", targets: ["LetsMove"]),
    ],
    targets: [
        .target(
            name: "LetsMove",
            path: "Sources",
            resources: [
                .process("Resources"),
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("."),
                .unsafeFlags(["-fno-objc-arc"]),
            ]
        ),
    ]
)
