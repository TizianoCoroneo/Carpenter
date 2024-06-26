
@_exported import Carpenter
@_exported import enum GraphViz.LayoutAlgorithm
@_exported import enum GraphViz.Format
import Foundation
import SwiftGraph
import GraphViz

struct CarpenterVisualizer {

    static func main() async throws {

        let arguments = ProcessInfo.processInfo.arguments

        guard arguments.count == 3 else {
            print("""
            Wrong number of arguments.

            You must provide as arguments two paths:
            - a path to a folder where to output the images,
            - a path to a JSON file that contains the encoded VisualizationBundle.
            """)
            return
        }

        let outputURL = URL(fileURLWithPath: arguments[1])

        let jsonDecoder = JSONDecoder()

        let bundleURL = URL(fileURLWithPath: arguments[2])
        let bundleData = try Data(contentsOf: bundleURL)
        let bundle = try jsonDecoder.decode(Carpenter.VisualizationBundle.self, from: bundleData)

        try await saveImage(
            name: "BuildGraph",
            bundle: bundle,
            mode: .builderDependency,
            removingTransitiveEdges: false,
            outputURL: outputURL)

        try await saveImage(
            name: "BuildGraph",
            bundle: bundle,
            mode: .builderDependency,
            removingTransitiveEdges: true,
            outputURL: outputURL)

        try await saveImage(
            name: "LateInitGraph",
            bundle: bundle,
            mode: .lateInitialization,
            removingTransitiveEdges: false,
            outputURL: outputURL)

        try await saveImage(
            name: "LateInitGraph",
            bundle: bundle,
            mode: .lateInitialization,
            removingTransitiveEdges: true,
            outputURL: outputURL)

        try await saveImage(
            name: "FullGraph",
            bundle: bundle,
            mode: .both,
            removingTransitiveEdges: false,
            outputURL: outputURL)

        try await saveImage(
            name: "FullGraph",
            bundle: bundle,
            mode: .both,
            removingTransitiveEdges: true,
            outputURL: outputURL)
    }

    public static func saveImage(
        name: String,
        bundle: Carpenter.VisualizationBundle,
        mode: Visualization,
        removingTransitiveEdges: Bool,
        outputURL: URL
    ) async throws {
        let buildImageData = try await visualize(
            bundle: bundle,
            mode: mode,
            removingTransitiveEdges: removingTransitiveEdges)

        try buildImageData.write(to: outputURL
            .appendingPathComponent("\(name)\(removingTransitiveEdges ? " - simplified" : "")")
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
        removingTransitiveEdges: Bool
    ) async throws -> Data {
        try await visualize(
            bundle: carpenter.exportToVisualizationBundle(),
            mode: mode,
            layoutAlgorithm: layoutAlgorithm,
            format: format,
            removingTransitiveEdges: removingTransitiveEdges)
    }

    public static func visualize(
        bundle: Carpenter.VisualizationBundle,
        mode: Visualization = .both,
        layoutAlgorithm: LayoutAlgorithm = .dot,
        format: Format = .jpg,
        removingTransitiveEdges: Bool
    ) async throws -> Data {

        var buildGraph = bundle.buildGraph
        var lateInitGraph = bundle.lateInitGraph

        precondition(buildGraph.isDAG, "The build graph needs to be a direct acyclic graph in order to create a visualization")
        precondition(lateInitGraph.isDAG, "The late initialization graph needs to be a direct acyclic graph in order to create a visualization")

        var graphViz = Graph(directed: true, strict: false)
        graphViz.rankDirection = .topToBottom
        graphViz.outputOrder = .nodesFirst

        if mode == .builderDependency || mode == .both {
            var builderGraph = Subgraph()

            if removingTransitiveEdges {
                buildGraph = buildGraph.transitiveReduction()!
            }

            for vertex in buildGraph.vertices {
                var node = Node(vertex)

                switch bundle.nodeKinds[vertex] {
                case .objectFactory: node.shape = .ellipse
                case .startupTask: node.shape = .rectangle
                case .protocolFactory: node.shape = .diamond
                default: break
                }

                if vertex != "()" {
                    graphViz.append(node)
                }

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
                lateInitGraph = lateInitGraph.transitiveReduction()!
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
            Renderer(layout: layoutAlgorithm, options: [])
                .render(graph: graphViz, to: format, completion: continuation.resume(with:))
        }
    }

    static func visualize(
        graph: UnweightedGraph<String>,
        mode: Visualization = .both,
        layoutAlgorithm: LayoutAlgorithm = .dot,
        format: Format = .jpg,
        removingTransitiveEdges: Bool
    ) async throws -> Data {

        precondition(graph.isDAG, "The graph needs to be a direct acyclic graph in order to create a visualization")

        var graph = graph

        var graphViz = Graph(directed: true, strict: false)
        graphViz.rankDirection = .topToBottom
        graphViz.outputOrder = .nodesFirst

        if mode == .builderDependency || mode == .both {
            var builderGraph = Subgraph()

            if removingTransitiveEdges {
                graph = graph.transitiveReduction()!
            }

            for vertex in graph.vertices {
                let node = Node(vertex)

                if vertex != "()" {
                    graphViz.append(node)
                }

                for neighbor in graph.neighborsForVertex(vertex) ?? [] {
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

        return try await withCheckedThrowingContinuation { continuation in
            Renderer(layout: layoutAlgorithm, options: [])
                .render(graph: graphViz, to: format, completion: continuation.resume(with:))
        }
    }
}


extension UnweightedGraph {

    func findAllPaths(fromIndex from: Int, toIndex to: Int) -> [[UnweightedEdge]] {
        var paths: [[UnweightedEdge]] = []
        var path: [UnweightedEdge] = []

        func findAllPathsRecursive(from: Int, to: Int) {
            let nextNodes = self.neighborsForIndex(from).compactMap(self.indexOfVertex(_:))
            for next in nextNodes {
                if next == to {
                    var newPath = [UnweightedEdge]()
                    for n in path {
                        newPath.append(n)
                    }
                    newPath.append(UnweightedEdge(u: from, v: next, directed: true))
                    paths.append(newPath)
                } else if !path.contains(where: { $0.v == next }) {
                    path.append(UnweightedEdge(
                        u: from,
                        v: next,
                        directed: true))
                    findAllPathsRecursive(from: next, to: to)
                    path.removeLast()
                }
            }
        }

        findAllPathsRecursive(from: from, to: to)

        return paths
    }

    /// Returns a new graph without all the transitive edges of the original graph.
    func transitiveReduction() -> UnweightedGraph<V>? where V: Hashable {
        guard self.isDAG else { return nil }

        var newGraph = UnweightedGraph<V>()

        newGraph.vertices = self.vertices
        newGraph.edges = self.edges

        for edge in self.edgeList() {
            let allPaths = self.findAllPaths(fromIndex: edge.u, toIndex: edge.v)

            if allPaths.contains(where: { path in !path.contains(edge) }) {
                newGraph.removeEdge(edge)
            }
        }

        return newGraph
    }

}

try await CarpenterVisualizer.main()
