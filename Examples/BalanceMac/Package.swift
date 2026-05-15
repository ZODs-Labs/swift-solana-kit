// swift-tools-version: 6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "BalanceMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BalanceMac", targets: ["BalanceMac"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .target(
            name: "BalanceMacCore",
            dependencies: [.product(name: "Kit", package: "swift-solana-kit")],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "BalanceMac",
            dependencies: ["BalanceMacCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "BalanceMacCoreTests",
            dependencies: ["BalanceMacCore"],
            swiftSettings: swiftSettings
        )
    ]
)
