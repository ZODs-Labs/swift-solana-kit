// swift-tools-version: 6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "AccountActivityIOS",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .executable(name: "AccountActivityIOS", targets: ["AccountActivityIOS"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .target(
            name: "AccountActivityIOSCore",
            dependencies: [.product(name: "Kit", package: "swift-solana-kit")],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "AccountActivityIOS",
            dependencies: ["AccountActivityIOSCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AccountActivityIOSCoreTests",
            dependencies: ["AccountActivityIOSCore"],
            swiftSettings: swiftSettings
        )
    ]
)
