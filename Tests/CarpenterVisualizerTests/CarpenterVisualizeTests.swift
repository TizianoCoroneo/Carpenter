import XCTest
import SwiftGraph
import CarpenterTestUtilities
@testable import CarpenterVisualizer

class TransitiveReductionTests: XCTestCase {

    final func testTransitiveReduction() async throws {
        let buildGraphURL = Bundle.buildGraphURL
        let lateInitGraphURL = Bundle.lateInitGraphURL

        let buildGraphData = try Data(contentsOf: buildGraphURL)
        let lateInitData = try Data(contentsOf: lateInitGraphURL)

        let decoder = JSONDecoder()

        let buildGraph = try decoder.decode(UnweightedGraph<String>.self, from: buildGraphData)
        let lateInitGraph = try decoder.decode(UnweightedGraph<String>.self, from: lateInitData)

        let reducedBuildGraph = try XCTUnwrap(buildGraph.transitiveReduction())

        XCTAssertEqual(buildGraph.vertices, reducedBuildGraph.vertices)
        XCTAssertNotEqual(buildGraph.edgeList(), reducedBuildGraph.edgeList())
    }
}

class DotCarpenterVisualizeTests: XCTestCase {

    var layoutAlgorithm: LayoutAlgorithm { .dot }

    override func setUp() {
        Carpenter.shared = .init()
    }

    override func tearDown() {
        Carpenter.shared = .init()
    }

    func testVisualizeGraph() async throws {
        Carpenter.shared = try .init {
            Dependency.i
            Dependency.keychain
            Dependency.authClient
            Dependency.urlSession
            Dependency.apiClient
        }

        try await save(
            name: "Build dependencies.jpg",
            CarpenterVisualizer.visualize(
                mode: .builderDependency,
                layoutAlgorithm: layoutAlgorithm))

        try await save(
            name: "Late initialization.jpg",
            CarpenterVisualizer.visualize(
                mode: .lateInitialization,
                layoutAlgorithm: layoutAlgorithm))

        try await save(
            name: "Everything.jpg",
            CarpenterVisualizer.visualize(
                mode: .both,
                layoutAlgorithm: layoutAlgorithm))
    }

    func testVisualizeGraphWithLateInitialization() async throws {
        Carpenter.shared = try .init {
            Dependency.i
            Dependency.keychain
            Dependency.authClient
            Dependency.urlSession
            Factory(ApiClient.init) { (x: inout ApiClient, k: (SixDependenciesObject, FiveDependenciesObject)) in
                x.i = k.0.i * 3
            }
            Dependency.threeDependenciesObject
            Dependency.fourDependenciesObject
            Dependency.fiveDependenciesObject
            Dependency.sixDependenciesObject
        } 

        try await save(
            name: "Build dependencies.jpg",
            CarpenterVisualizer.visualize(
                mode: .builderDependency,
                layoutAlgorithm: layoutAlgorithm,
                removingTransitiveEdges: false))

        try await save(
            name: "Build dependencies simplified.jpg",
            CarpenterVisualizer.visualize(
                mode: .builderDependency,
                layoutAlgorithm: layoutAlgorithm,
                removingTransitiveEdges: true))

        try await save(
            name: "Late initialization.jpg",
            CarpenterVisualizer.visualize(
                mode: .lateInitialization,
                layoutAlgorithm: layoutAlgorithm))

        try await save(
            name: "Late initialization simplified.jpg",
            CarpenterVisualizer.visualize(
                mode: .lateInitialization,
                layoutAlgorithm: layoutAlgorithm,
                removingTransitiveEdges: true))

        try await save(
            name: "Everything.jpg",
            CarpenterVisualizer.visualize(
                mode: .both,
                layoutAlgorithm: layoutAlgorithm))

        try await save(
            name: "Everything simplified.jpg",
            CarpenterVisualizer.visualize(
                mode: .both,
                layoutAlgorithm: layoutAlgorithm,
                removingTransitiveEdges: true))
    }

    private func save(name: String, _ data: Data) {
        let attachment = XCTAttachment(image: NSImage(data: data)!)
        attachment.lifetime = .keepAlways
        attachment.name = name
        self.add(attachment)
    }
}

class CircoCarpenterVisualizeTests: DotCarpenterVisualizeTests {
    override var layoutAlgorithm: LayoutAlgorithm { .circo }
}

class FDPCarpenterVisualizeTests: DotCarpenterVisualizeTests {
    override var layoutAlgorithm: LayoutAlgorithm { .fdp }
}

class NeatoCarpenterVisualizeTests: DotCarpenterVisualizeTests {
    override var layoutAlgorithm: LayoutAlgorithm { .neato }
}

class PatchworkCarpenterVisualizeTests: DotCarpenterVisualizeTests {
    override var layoutAlgorithm: LayoutAlgorithm { .patchwork }
}

class SfdpCarpenterVisualizeTests: DotCarpenterVisualizeTests {
    override var layoutAlgorithm: LayoutAlgorithm { .sfdp }
}

class TwopiCarpenterVisualizeTests: DotCarpenterVisualizeTests {
    override var layoutAlgorithm: LayoutAlgorithm { .twopi }
}