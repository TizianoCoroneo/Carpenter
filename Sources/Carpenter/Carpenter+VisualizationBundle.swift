
import SwiftGraph

// MARK: - Visualization helper

public extension Carpenter {
    struct VisualizationBundle: Codable {
        public let buildGraph: UnweightedGraph<String>
        public let lateInitGraph: UnweightedGraph<String>
        public let nodeKinds: [String: AnyFactory.Kind]
    }

    private func representableGraph(
        _ graph: UnweightedGraph<AnyDependencyKey>
    ) -> UnweightedGraph<String> {
        let new = UnweightedGraph<String>(vertices: graph.vertices.map { $0.displayName() })
        for edge in graph.edgeList() { new.addEdge(edge, directed: edge.directed) }
        return new
    }

    func exportToVisualizationBundle() -> VisualizationBundle {
        .init(
            buildGraph: representableGraph(dependencyGraph),
            lateInitGraph: representableGraph(lateInitDependencyGraph),
            nodeKinds: Dictionary(uniqueKeysWithValues: factoryRegistry
                .map { ($0.displayName(), $1.kind) }))
    }
}
