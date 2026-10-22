// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FishingCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FishingCore",
            targets: ["FishingCore"]
        ),
        .library(
            name: "FishingDatabase",
            targets: ["FishingDatabase"]
        ),
        .library(
            name: "FishingGameApp",
            targets: ["FishingGameApp"]
        )
    ],
    targets: [
        .target(
            name: "FishingCore",
            dependencies: [],
            path: "Sources/FishingCore"
        ),
        .target(
            name: "FishingDatabase",
            dependencies: ["FishingCore"],
            path: "Sources/FishingDatabase",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .target(
            name: "FishingGameApp",
            dependencies: ["FishingCore", "FishingDatabase"],
            path: "Sources/FishingGameApp"
        ),
        .testTarget(
            name: "FishingCoreTests",
            dependencies: ["FishingCore"],
            path: "Tests/FishingCoreTests"
        ),
        .testTarget(
            name: "FishingDatabaseTests",
            dependencies: ["FishingCore", "FishingDatabase"],
            path: "Tests/FishingDatabaseTests"
        ),
        .testTarget(
            name: "FishingGameAppTests",
            dependencies: ["FishingCore", "FishingDatabase", "FishingGameApp"],
            path: "Tests/FishingGameAppTests"
        )
    ]
)