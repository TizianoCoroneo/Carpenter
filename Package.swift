// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Carpenter",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Carpenter",
            targets: ["Carpenter"]),
    ],
    dependencies: [
         .package(url: "https://github.com/davecom/SwiftGraph", from: "3.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Carpenter",
            dependencies: [
                "SwiftGraph"
            ]),
        .testTarget(
            name: "CarpenterTests",
            dependencies: ["Carpenter"]),
    ]
)
