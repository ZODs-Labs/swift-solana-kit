// swift-tools-version: 6.0
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableExperimentalFeature("StrictConcurrency")
]

let package = Package(
    name: "AirdropIOS",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .executable(name: "AirdropIOS", targets: ["AirdropIOS"])
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .target(
            name: "AirdropIOSCore",
            dependencies: [.product(name: "Kit", package: "swift-solana-kit")],
            swiftSettings: swiftSettings
        ),
        .executableTarget(
            name: "AirdropIOS",
            dependencies: ["AirdropIOSCore"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "AirdropIOSCoreTests",
            dependencies: ["AirdropIOSCore"],
            swiftSettings: swiftSettings
        )
    ]
)
