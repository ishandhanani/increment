// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "IncrementFeature",
    platforms: [.iOS(.v18)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "IncrementFeature",
            targets: ["IncrementFeature"]
        ),
        .executable(
            name: "IncrementAppEntry",
            targets: ["IncrementAppEntry"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.

        // Core library - all business logic, models, views (no @main)
        .target(
            name: "IncrementFeature"
        ),

        // App entry point - only contains @main annotation
        // Separated to prevent duplicate _main symbol in tests
        .executableTarget(
            name: "IncrementAppEntry",
            dependencies: ["IncrementFeature"]
        ),

        // Tests - depends on library only, not the app entry point
        .testTarget(
            name: "IncrementFeatureTests",
            dependencies: [
                "IncrementFeature"
            ]
        ),
    ]
)
