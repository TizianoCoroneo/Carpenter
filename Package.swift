// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation
import os.log

let logger = Logger(subsystem: "Carpenter", category: "Packaging")
logger.log("Hello Carpenter!")

let buildBenchmark = false
let buildVisualizer = false

let package = Package(
    name: "Carpenter",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(
            name: "Carpenter",
            targets: ["Carpenter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/mrwerdo/SwiftGraph", branch: "master")
    ],
    targets: [
        // MARK: - Source

        .target(
            name: "Carpenter",
            dependencies: [
                "SwiftGraph"
            ]
            , swiftSettings: [
//                .unsafeFlags(["-no-whole-module-optimization"]) // Without this flag we crash the 5.10 compiler
            ]
        ),

        .target(
            name: "CarpenterTestUtilities",
            dependencies: [
                "Carpenter",
            ],
            resources: [
                .copy("VisualizationBundle.json"),
            ]),

        // MARK: - Tests

        .testTarget(
            name: "CarpenterTests",
            dependencies: ["CarpenterTestUtilities"]),
    ]
)

if hasEnvironmentVariable("VISUALIZER") || buildVisualizer {
    logger.log("Building with visualizer.")

    package.dependencies.append(.package(url: "https://github.com/SwiftDocOrg/GraphViz", from: "0.4.1"))
    package.targets.append(
        .executableTarget(
            name: "CarpenterVisualizer",
            dependencies: [
                "Carpenter",
                "GraphViz",
            ]))
    package.products.append(
        .executable(
            name: "CarpenterVisualizer",
            targets: [
                "CarpenterVisualizer"
            ]))
    package.targets.append(
        .testTarget(
            name: "CarpenterVisualizerTests",
            dependencies: ["CarpenterTestUtilities", "CarpenterVisualizer"]))
}

if hasEnvironmentVariable("BENCHMARK") || buildBenchmark {
    logger.log("Building with benchmarks.")

    package.platforms = [
        .macOS(.v13),
        .iOS(.v13),
    ]

    package.dependencies.append(.package(url: "https://github.com/ordo-one/package-benchmark", .upToNextMajor(from: "1.4.0")))
    package.targets.append(
        .executableTarget(
            name: "CarpenterBenchmark",
            dependencies: [
                .product(name: "Benchmark", package: "package-benchmark"),
                "Carpenter",
            ],
            path: "Benchmarks/CarpenterBenchmark",
            plugins: [
                .plugin(name: "BenchmarkPlugin", package: "package-benchmark")
            ]
        ))
}

func hasEnvironmentVariable(_ name: String) -> Bool {
    ProcessInfo.processInfo.environment[name] != nil
}

// Benchmark of Benchmark
