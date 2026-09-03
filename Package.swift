// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "MacGadgets",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacGadgets", targets: ["MacGadgets"])
    ],
    targets: [
        .executableTarget(
            name: "MacGadgets",
            path: "Sources/MacGadgets"
        ),
        .testTarget(
            name: "MacGadgetsTests",
            dependencies: ["MacGadgets"],
            path: "Tests"
        )
    ]
)
