import XCTest
import CarpenterTestUtilities
@testable import Carpenter
@testable import CarpenterVisualizer

class TransitiveReductionTests: XCTestCase {

    func visualizationBundle() throws -> Carpenter.VisualizationBundle {
        let bundleURL = Bundle.visualizationBundleURL
        let bundleData = try Data(contentsOf: bundleURL)
        let decoder = JSONDecoder()
        let visualizationBundle = try decoder.decode(Carpenter.VisualizationBundle.self, from: bundleData)
        return visualizationBundle
    }

    final func testTransitiveReduction() async throws {
        let visualizationBundle = try visualizationBundle()

        let originalGraph = visualizationBundle.buildGraph

        let reducedBuildGraph = try XCTUnwrap(originalGraph.transitiveReduction())

        XCTAssertEqual(originalGraph.vertices, reducedBuildGraph.vertices)

        let originalEdgeList = originalGraph.edgeList()
        let reducedEdgeList = reducedBuildGraph.edgeList()

        let originalEdgeNames = originalEdgeList.map { edge in
            "\(originalGraph.vertexAtIndex(edge.u)) -> \(originalGraph.vertexAtIndex(edge.v))"
        }
        let reducedEdgeNames = reducedEdgeList.map { edge in
            "\(reducedBuildGraph.vertexAtIndex(edge.u)) -> \(reducedBuildGraph.vertexAtIndex(edge.v))"
        }

        let removedEdges = Set(originalEdgeNames).subtracting(Set(reducedEdgeNames))

        print(removedEdges)

        XCTAssertNotEqual(originalEdgeNames, reducedEdgeNames)

        let data = try await CarpenterVisualizer.visualize(
            bundle: visualizationBundle,
            removingTransitiveEdges: true)

        let attachment = XCTAttachment(image: NSImage(data: data)!)
        attachment.name = "Graph"
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    final func testFindAllPaths() async throws {
        let visualizationBundle = try visualizationBundle()

        var graph = visualizationBundle.buildGraph

        let impactedNodes: Set<String> = [
            "UIWindow",
            "TicketSwapUserContext",
            "AppTabWireframe",
            "MainTabWireframe",
        ]

        graph.vertices
            .filter { !impactedNodes.contains($0) }
            .forEach { graph.removeVertex($0) }

        XCTAssertTrue(graph.edgeExists(from: "TicketSwapUserContext", to: "UIWindow"))
        XCTAssertTrue(graph.edgeExists(from: "TicketSwapUserContext", to: "AppTabWireframe"))
        XCTAssertTrue(graph.edgeExists(from: "AppTabWireframe", to: "MainTabWireframe"))
        XCTAssertTrue(graph.edgeExists(from: "MainTabWireframe", to: "UIWindow"))

        let paths = graph.findAllPaths(
            fromIndex: graph.indexOfVertex("TicketSwapUserContext")!,
            toIndex: graph.indexOfVertex("UIWindow")!)

        let printablePaths = paths.map { path in
            path.map { edge in
                "\(graph.vertexAtIndex(edge.u)) -> \(graph.vertexAtIndex(edge.v))"
            }
        }

        print(printablePaths)

        XCTAssertEqual(paths.count, 2)

        guard paths.count == 2 else { return }

        XCTAssertEqual(printablePaths[0], [
            "TicketSwapUserContext -> AppTabWireframe",
            "AppTabWireframe -> MainTabWireframe",
            "MainTabWireframe -> UIWindow"
        ])
        XCTAssertEqual(printablePaths[1], [
            "TicketSwapUserContext -> UIWindow"
        ])

        let data = try await CarpenterVisualizer.visualize(
            graph: graph,
            removingTransitiveEdges: false)

        let attachment = XCTAttachment(image: NSImage(data: data)!)
        attachment.name = "Graph"
        attachment.lifetime = .keepAlways
        self.add(attachment)
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

        try Carpenter.shared.finalizeGraph()

        try await save(
            name: "Build dependencies.jpg",
            CarpenterVisualizer.visualize(
                mode: .builderDependency,
                layoutAlgorithm: layoutAlgorithm,
                removingTransitiveEdges: false))

        try await save(
            name: "Late initialization.jpg",
            CarpenterVisualizer.visualize(
                mode: .lateInitialization,
                layoutAlgorithm: layoutAlgorithm,
                removingTransitiveEdges: false))

        try await save(
            name: "Everything.jpg",
            CarpenterVisualizer.visualize(
                mode: .both,
                layoutAlgorithm: layoutAlgorithm,
                removingTransitiveEdges: false))
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

        try Carpenter.shared.finalizeGraph()

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
                layoutAlgorithm: layoutAlgorithm,
                removingTransitiveEdges: false))

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
                layoutAlgorithm: layoutAlgorithm,
                removingTransitiveEdges: false))

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
