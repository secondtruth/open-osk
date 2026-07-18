// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OpenOSK",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "openosk", targets: ["OpenOSK"]),
        .library(name: "OpenOSKCore", targets: ["OpenOSKCore"]),
    ],
    targets: [
        .target(
            name: "OpenOSKCore",
            resources: [
                .copy("Resources")
            ]
        ),
        .executableTarget(
            name: "OpenOSK",
            dependencies: ["OpenOSKCore"]
        ),
        .testTarget(
            name: "OpenOSKCoreTests",
            dependencies: ["OpenOSKCore"]
        ),
    ]
)
