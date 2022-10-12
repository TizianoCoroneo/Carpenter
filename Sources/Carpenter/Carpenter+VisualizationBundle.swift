
import SwiftGraph

// MARK: - Visualization helper

public extension Carpenter {
    struct VisualizationBundle: Codable {
        public let buildGraph: UnweightedGraph<Vertex>
        public let lateInitGraph: UnweightedGraph<Vertex>
        public let nodeKinds: [Vertex: AnyFactory.Kind]
    }

    func exportToVisualizationBundle() -> VisualizationBundle {
        .init(
            buildGraph: self.dependencyGraph,
            lateInitGraph: self.lateInitDependencyGraph,
            nodeKinds: self.factoryRegistry.mapValues(\.kind))
    }
}
