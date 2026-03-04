// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "LetsMove",
    defaultLocalization: "en",
    platforms: [.macOS(.v11)],
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
