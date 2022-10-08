// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Carpenter",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Carpenter",
            targets: ["Carpenter"]),
        .library(
            name: "CarpenterSwiftUI",
            targets: ["CarpenterSwiftUI"]),
        .library(
            name: "CarpenterVisualize",
            targets: ["CarpenterVisualize"])
    ],
    dependencies: [
         .package(url: "https://github.com/davecom/SwiftGraph", from: "3.1.0"),
         .package(url: "https://github.com/SwiftDocOrg/GraphViz", from: "0.4.1"),
    ],
    targets: [

        // MARK: - Source

        .target(
            name: "Carpenter",
            dependencies: [
                "SwiftGraph"
            ]),

        .target(
            name: "CarpenterSwiftUI",
            dependencies: [
                "Carpenter"
            ]),

        .target(
            name: "CarpenterVisualize",
            dependencies: [
                "Carpenter",
                "GraphViz",
            ]),

        .target(
            name: "CarpenterTestUtilities",
            dependencies: [
                "Carpenter",
            ]),

        // MARK: - Tests

        .testTarget(
            name: "CarpenterTests",
            dependencies: ["CarpenterTestUtilities"]),

        .testTarget(
            name: "CarpenterSwiftUITests",
            dependencies: ["CarpenterTestUtilities", "CarpenterSwiftUI"]),

        .testTarget(
            name: "CarpenterVisualizeTests",
            dependencies: ["CarpenterTestUtilities", "CarpenterVisualize"]),
    ]
)
