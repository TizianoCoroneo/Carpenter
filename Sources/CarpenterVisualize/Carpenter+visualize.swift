//
//  File.swift
//  
//
//  Created by Tiziano Coroneo on 08/10/2022.
//

@_exported import Carpenter
@_exported import enum GraphViz.LayoutAlgorithm
@_exported import enum GraphViz.Format
import Foundation
import GraphViz

public extension Carpenter {

    enum Visualization {
        case builderDependency
        case lateInitialization
        case both
    }

    func visualize(
        mode: Visualization = .both,
        layoutAlgorithm: LayoutAlgorithm = .dot,
        format: Format = .jpg,
        removingTransitiveEdges: Bool = false
    ) async throws -> Data {

        var graphViz = Graph(directed: true, strict: false)
        graphViz.rankDirection = .topToBottom
        graphViz.outputOrder = .nodesFirst

        if mode == .builderDependency || mode == .both {
            var builderGraph = Subgraph()

            for vertex in self.dependencyGraph.vertices {
                for neighbor in self.dependencyGraph.neighborsForVertex(vertex) ?? [] {
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
            var lateInitGraph = Subgraph()

            for vertex in self.lateInitDependencyGraph.vertices {
                for neighbor in self.lateInitDependencyGraph.neighborsForVertex(vertex) ?? [] {
                    var e = Edge(
                        from: neighbor,
                        to: vertex,
                        direction: .forward)
                    e.style = .dashed
                    e.strokeColor = .rgb(red: 0, green: 128, blue: 255)
                    e.constraint = false
                    e.decorate = true
                    lateInitGraph.append(e)
                }
            }

            graphViz.append(lateInitGraph)
        }

        return try await withCheckedThrowingContinuation { continuation in
            // Workaround to access the `removeEdgesImpliedByTransitivity` option.
            let options: Renderer.Options = removingTransitiveEdges ? [Renderer.Options(rawValue: 1 << 0)] : []

            Renderer(layout: layoutAlgorithm, options: options)
                .render(graph: graphViz, to: format, completion: continuation.resume(with:))
        }
    }
}
