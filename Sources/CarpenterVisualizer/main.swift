
@_exported import Carpenter
@_exported import enum GraphViz.LayoutAlgorithm
@_exported import enum GraphViz.Format
import Foundation
import SwiftGraph
import GraphViz

struct CarpenterVisualizer {

    static func main() async throws {

        let arguments = ProcessInfo.processInfo.arguments

        guard arguments.count == 4 else {
            print("""
            Wrong number of arguments.

            You must provide as arguments two paths:
            - a path to a folder where to output the images,
            - a path to a JSON file that contains the build dependency graph,
            - a path to a JSON file that contains the late initialization graph.
            """)
            return
        }

        let outputURL = URL(fileURLWithPath: arguments[1])

        let jsonDecoder = JSONDecoder()

        let buildURL = URL(fileURLWithPath: arguments[2])
        print(buildURL)
        let buildData = try Data(contentsOf: buildURL)
        let buildGraph = try jsonDecoder.decode(UnweightedGraph<String>.self, from: buildData)

        let lateInitURL = URL(fileURLWithPath: arguments[3])
        let lateInitData = try Data(contentsOf: lateInitURL)
        let lateInitGraph = try jsonDecoder.decode(UnweightedGraph<String>.self, from: lateInitData)

        try await saveImage(
            name: "BuildGraph",
            buildGraph: buildGraph,
            lateInitGraph: lateInitGraph,
            mode: .builderDependency,
            removingTransitiveEdges: false,
            outputURL: outputURL)

        try await saveImage(
            name: "BuildGraph",
            buildGraph: buildGraph,
            lateInitGraph: lateInitGraph,
            mode: .builderDependency,
            removingTransitiveEdges: true,
            outputURL: outputURL)

        try await saveImage(
            name: "LateInitGraph",
            buildGraph: buildGraph,
            lateInitGraph: lateInitGraph,
            mode: .lateInitialization,
            removingTransitiveEdges: false,
            outputURL: outputURL)

        try await saveImage(
            name: "LateInitGraph",
            buildGraph: buildGraph,
            lateInitGraph: lateInitGraph,
            mode: .lateInitialization,
            removingTransitiveEdges: true,
            outputURL: outputURL)

        try await saveImage(
            name: "FullGraph",
            buildGraph: buildGraph,
            lateInitGraph: lateInitGraph,
            mode: .both,
            removingTransitiveEdges: false,
            outputURL: outputURL)

        try await saveImage(
            name: "FullGraph",
            buildGraph: buildGraph,
            lateInitGraph: lateInitGraph,
            mode: .both,
            removingTransitiveEdges: true,
            outputURL: outputURL)
    }

    public static func saveImage(
        name: String,
        buildGraph: UnweightedGraph<String>,
        lateInitGraph: UnweightedGraph<String>,
        mode: Visualization,
        removingTransitiveEdges: Bool,
        outputURL: URL
    ) async throws {
        let buildImageData = try await visualize(
            buildGraph: buildGraph,
            lateInitGraph: lateInitGraph,
            mode: mode,
            removingTransitiveEdges: removingTransitiveEdges)

        try buildImageData.write(to: outputURL
            .appendingPathComponent("\(name)\(removingTransitiveEdges ? "- simplified" : "")")
            .appendingPathExtension("jpg"))
    }

    public enum Visualization {
        case builderDependency
        case lateInitialization
        case both
    }

    public static func visualize(
        _ carpenter: Carpenter = .shared,
        mode: Visualization = .both,
        layoutAlgorithm: LayoutAlgorithm = .dot,
        format: Format = .jpg,
        removingTransitiveEdges: Bool = false
    ) async throws -> Data {
        try await visualize(
            buildGraph: carpenter.dependencyGraph,
            lateInitGraph: carpenter.lateInitDependencyGraph,
            mode: mode,
            layoutAlgorithm: layoutAlgorithm,
            format: format,
            removingTransitiveEdges: removingTransitiveEdges)
    }

    public static func visualize(
        buildGraph: UnweightedGraph<String>,
        lateInitGraph: UnweightedGraph<String>,
        mode: Visualization = .both,
        layoutAlgorithm: LayoutAlgorithm = .dot,
        format: Format = .jpg,
        removingTransitiveEdges: Bool = false
    ) async throws -> Data {

        var buildGraph = buildGraph
        var lateInitGraph = lateInitGraph

        var graphViz = Graph(directed: true, strict: false)
        graphViz.rankDirection = .topToBottom
        graphViz.outputOrder = .nodesFirst

        if mode == .builderDependency || mode == .both {
            var builderGraph = Subgraph()

            if removingTransitiveEdges {
                buildGraph = buildGraph.transitiveReduction() ?? buildGraph
            }

            for vertex in buildGraph.vertices {
                for neighbor in buildGraph.neighborsForVertex(vertex) ?? [] {
                    var e = Edge(
                        from: neighbor,
                        to: vertex,
                        direction: .forward)
                    e.strokeColor = .rgb(red: 255, green: 0, blue: 0)
                    builderGraph.append(e)
                }
            }

            graphViz.append(builderGraph)
        }

        if mode == .lateInitialization || mode == .both {
            var graph = Subgraph()

            if removingTransitiveEdges {
                lateInitGraph = lateInitGraph.transitiveReduction() ?? lateInitGraph
            }

            for vertex in lateInitGraph.vertices {
                for neighbor in lateInitGraph.neighborsForVertex(vertex) ?? [] {
                    var e = Edge(
                        from: neighbor,
                        to: vertex,
                        direction: .forward)
                    e.style = .dashed
                    e.strokeColor = .rgb(red: 0, green: 128, blue: 255)
                    e.constraint = false
                    e.decorate = true
                    graph.append(e)
                }
            }

            graphViz.append(graph)
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Workaround to access the `removeEdgesImpliedByTransitivity` option.
//            let options: Renderer.Options = removingTransitiveEdges ? [Renderer.Options(rawValue: 1 << 0)] : []

            Renderer(layout: layoutAlgorithm, options: [])
                .render(graph: graphViz, to: format, completion: continuation.resume(with:))
        }
    }
}


extension UnweightedGraph {

    /// Returns a new graph without all the transitive edges of the original graph.
    func transitiveReduction() -> UnweightedGraph<V>? where V: Hashable {
        guard self.isDAG else { return nil }

        var newGraph = UnweightedGraph<V>()

        newGraph.vertices = self.vertices
        newGraph.edges = self.edges

        for edge in newGraph.edgeList() {
            let uVertex = newGraph.vertexAtIndex(edge.u)
            let vVertex = newGraph.vertexAtIndex(edge.v)

            let allPaths = newGraph.findAllDfs(
                from: uVertex,
                goalTest: { $0 == vVertex })

            if allPaths.contains(where: { path in !path.contains(edge) }) {
                newGraph.removeEdge(edge)
            }
        }

        return newGraph
    }

}

try await CarpenterVisualizer.main()
