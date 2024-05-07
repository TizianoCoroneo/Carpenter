//
//  UnweightedGraph.swift
//  SwiftGraph
//
//  Copyright (c) 2014-2019 David Kopec
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.

/// An implementation of Graph with some convenience methods for adding and removing UnweightedEdges. WeightedEdges may be added to an UnweightedGraph but their weights will be ignored.
public struct UnweightedGraph<V: Equatable>: CustomStringConvertible, Collection {
    public var vertices: [V] = [V]()
    public var edges: [[UnweightedEdge]] = [[UnweightedEdge]]() //adjacency lists
    
    public init() {
    }
    
    public init(vertices: [V]) {
        for vertex in vertices {
            _ = self.addVertex(vertex)
        }
    }
    
    public enum Keys: CodingKey {
        case vertices
        case edges
    }
    
    public init(from decoder: Decoder) throws where V: Decodable {
        let container = try decoder.container(keyedBy: Keys.self)
        let vertices = try container.decode([V].self, forKey: .vertices)
        let edges: [[UnweightedEdge]] = try container.decode([[UnweightedEdge]].self, forKey: .edges)
        self.init(vertices: vertices)
        for edge in edges.lazy.flatMap({$0}) {
            addEdge(edge, directed: edge.directed)
        }
    }
    
    /// Add an edge to the graph.
    ///
    /// - parameter e: The edge to add.
    /// - parameter directed: If false, undirected edges are created.
    ///                       If true, a reversed edge is also created.
    ///                       Default is false.
    public mutating func addEdge(_ e: UnweightedEdge, directed: Bool) {
        edges[e.u].append(e)
        if !directed && e.u != e.v {
            edges[e.v].append(e.reversed())
        }
    }
    
    /// Add a vertex to the graph.
    ///
    /// - parameter v: The vertex to be added.
    /// - returns: The index where the vertex was added.
    public mutating func addVertex(_ v: V) -> Int {
        vertices.append(v)
        edges.append([UnweightedEdge]())
        return vertices.count - 1
    }

    /// Initialize an UnweightedGraph consisting of path.
    ///
    /// The resulting graph has the vertices in path and an edge between
    /// each pair of consecutive vertices in path.
    ///
    /// If path is an empty array, the resulting graph is the empty graph.
    /// If path is an array with a single vertex, the resulting graph has that vertex and no edges.
    ///
    /// - Parameters:
    ///   - path: An array of vertices representing a path.
    ///   - directed: If false, undirected edges are created.
    ///               If true, edges are directed from vertex i to vertex i+1 in path.
    ///               Default is false.
    public static func withPath(_ path: [V], directed: Bool = false) -> Self {
        var g = Self(vertices: path)

        guard path.count >= 2 else {
            return g
        }

        for i in 0..<path.count - 1 {
            g.addEdge(fromIndex: i, toIndex: i+1, directed: directed)
        }
        return g
    }

    /// Initialize an UnweightedGraph consisting of cycle.
    ///
    /// The resulting graph has the vertices in cycle and an edge between
    /// each pair of consecutive vertices in cycle,
    /// plus an edge between the last and the first vertices.
    ///
    /// If cycle is an empty array, the resulting graph is the empty graph.
    /// If cycle is an array with a single vertex, the resulting graph has the vertex
    /// and a single edge to itself if directed is true.
    /// If directed is false the resulting graph has the vertex and two edges to itself.
    ///
    /// - Parameters:
    ///   - cycle: An array of vertices representing a cycle.
    ///   - directed: If false, undirected edges are created.
    ///               If true, edges are directed from vertex i to vertex i+1 in cycle.
    ///               Default is false.
    public static func withCycle(_ cycle: [V], directed: Bool = false) -> Self {
        var g = Self.withPath(cycle, directed: directed)
        if cycle.count > 0 {
            g.addEdge(fromIndex: cycle.count-1, toIndex: 0, directed: directed)
        }
        return g
    }
    
    /// This is a convenience method that adds an unweighted edge.
    ///
    /// - parameter from: The starting vertex's index.
    /// - parameter to: The ending vertex's index.
    /// - parameter directed: Is the edge directed? (default `false`)
    public mutating func addEdge(fromIndex: Int, toIndex: Int, directed: Bool = false) {
        addEdge(UnweightedEdge(u: fromIndex, v: toIndex, directed: directed), directed: directed)
    }
    
    /// This is a convenience method that adds an unweighted, undirected edge between the first occurence of two vertices. It takes O(n) time.
    ///
    /// - parameter from: The starting vertex.
    /// - parameter to: The ending vertex.
    /// - parameter directed: Is the edge directed? (default `false`)
    public mutating func addEdge(from: V, to: V, directed: Bool = false) {
        if let u = indexOfVertex(from), let v = indexOfVertex(to) {
            addEdge(UnweightedEdge(u: u, v: v, directed: directed), directed: directed)
        }
    }

    /// Check whether there is an edge from one vertex to another vertex.
    ///
    /// - parameter from: The index of the starting vertex of the edge.
    /// - parameter to: The index of the ending vertex of the edge.
    /// - returns: True if there is an edge from the starting vertex to the ending vertex.
    public func edgeExists(fromIndex: Int, toIndex: Int) -> Bool {
        // The directed property of this fake edge is ignored, since it's not taken into account
        // for equality.
        return edgeExists(UnweightedEdge(u: fromIndex, v: toIndex, directed: true))
    }

    /// Check whether there is an edge from one vertex to another vertex.
    ///
    /// Note this will look at the first occurence of each vertex.
    /// Also returns false if either of the supplied vertices cannot be found in the graph.
    ///
    /// - parameter from: The starting vertex of the edge.
    /// - parameter to: The ending vertex of the edge.
    /// - returns: True if there is an edge from the starting vertex to the ending vertex.
    public func edgeExists(from: V, to: V) -> Bool {
        if let u = indexOfVertex(from) {
            if let v = indexOfVertex(to) {
                return edgeExists(fromIndex: u, toIndex: v)
            }
        }
        return false
    }

    /// How many vertices are in the graph?
    public var vertexCount: Int {
        return vertices.count
    }

    /// How many edges are in the graph?
    public var edgeCount: Int {
        return edges.joined().count
    }

    /// Returns a list of all the edges, undirected edges are only appended once.
    public func edgeList() -> [UnweightedEdge] {
        let edges = self.edges
        var edgeList = [UnweightedEdge]()
        for i in edges.indices {
            let edgesForVertex = edges[i]
            for j in edgesForVertex.indices {
                let edge = edgesForVertex[j]
                // We only want to append undirected edges once, so we do it when we find it on the
                // vertex with lowest index.
                if edge.directed || edge.v >= edge.u {
                    edgeList.append(edge)
                }
            }
        }
        return edgeList
    }

    /// Get a vertex by its index.
    ///
    /// - parameter index: The index of the vertex.
    /// - returns: The vertex at i.
    public func vertexAtIndex(_ index: Int) -> V {
        return vertices[index]
    }

    /// Find the first occurence of a vertex if it exists.
    ///
    /// - parameter vertex: The vertex you are looking for.
    /// - returns: The index of the vertex. Return nil if it can't find it.

    public func indexOfVertex(_ vertex: V) -> Int? {
        if let i = vertices.firstIndex(of: vertex) {
            return i
        }
        return nil;
    }

    /// Find all of the neighbors of a vertex at a given index.
    ///
    /// - parameter index: The index for the vertex to find the neighbors of.
    /// - returns: An array of the neighbor vertices.
    public func neighborsForIndex(_ index: Int) -> [V] {
        return edges[index].map({self.vertices[$0.v]})
    }

    /// Find all of the neighbors of a given Vertex.
    ///
    /// - parameter vertex: The vertex to find the neighbors of.
    /// - returns: An optional array of the neighbor vertices.
    public func neighborsForVertex(_ vertex: V) -> [V]? {
        if let i = indexOfVertex(vertex) {
            return neighborsForIndex(i)
        }
        return nil
    }

    /// Find all of the edges of a vertex at a given index.
    ///
    /// - parameter index: The index for the vertex to find the children of.
    public func edgesForIndex(_ index: Int) -> [UnweightedEdge] {
        return edges[index]
    }

    /// Find all of the edges of a given vertex.
    ///
    /// - parameter vertex: The vertex to find the edges of.
    public func edgesForVertex(_ vertex: V) -> [UnweightedEdge]? {
        if let i = indexOfVertex(vertex) {
            return edgesForIndex(i)
        }
        return nil
    }

    /// Find the first occurence of a vertex.
    ///
    /// - parameter vertex: The vertex you are looking for.
    public func vertexInGraph(vertex: V) -> Bool {
        if let _ = indexOfVertex(vertex) {
            return true
        }
        return false
    }

    /// Removes all edges in both directions between vertices at indexes from & to.
    ///
    /// - parameter from: The starting vertex's index.
    /// - parameter to: The ending vertex's index.
    /// - parameter bidirectional: Remove edges coming back (to -> from)
    public mutating func removeAllEdges(from: Int, to: Int, bidirectional: Bool = true) {
        edges[from].removeAll(where: { $0.v == to })

        if bidirectional {
            edges[to].removeAll(where: { $0.v == from })
        }
    }

    /// Removes all edges in both directions between two vertices.
    ///
    /// - parameter from: The starting vertex.
    /// - parameter to: The ending vertex.
    /// - parameter bidirectional: Remove edges coming back (to -> from)
    public mutating func removeAllEdges(from: V, to: V, bidirectional: Bool = true) {
        if let u = indexOfVertex(from) {
            if let v = indexOfVertex(to) {
                removeAllEdges(from: u, to: v, bidirectional: bidirectional)
            }
        }
    }

    /// Removes a vertex at a specified index, all of the edges attached to it, and renumbers the indexes of the rest of the edges.
    ///
    /// - parameter index: The index of the vertex.
    public mutating func removeVertexAtIndex(_ index: Int) {
        //remove all edges ending at the vertex, first doing the ones below it
        //renumber edges that end after the index
        for j in 0..<index {
            var toRemove: [Int] = [Int]()
            for l in 0..<edges[j].count {
                if edges[j][l].v == index {
                    toRemove.append(l)
                    continue
                }
                if edges[j][l].v > index {
                    edges[j][l].v -= 1
                }
            }
            for f in toRemove.reversed() {
                edges[j].remove(at: f)
            }
        }

        //remove all edges after the vertex index wise
        //renumber all edges after the vertex index wise
        for j in (index + 1)..<edges.count {
            var toRemove: [Int] = [Int]()
            for l in 0..<edges[j].count {
                if edges[j][l].v == index {
                    toRemove.append(l)
                    continue
                }
                edges[j][l].u -= 1
                if edges[j][l].v > index {
                    edges[j][l].v -= 1
                }
            }
            for f in toRemove.reversed() {
                edges[j].remove(at: f)
            }
        }
        //println(self)
        //remove the actual vertex and its edges
        edges.remove(at: index)
        vertices.remove(at: index)
    }

    /// Removes the first occurence of a vertex, all of the edges attached to it, and renumbers the indexes of the rest of the edges.
    ///
    /// - parameter vertex: The vertex to be removed..
    public mutating func removeVertex(_ vertex: V) {
        if let i = indexOfVertex(vertex) {
            removeVertexAtIndex(i)
        }
    }

    /// Check whether an edge is in the graph or not.
    ///
    /// - parameter edge: The edge to find in the graph.
    /// - returns: True if the edge exists, and false otherwise.
    public func edgeExists(_ edge: UnweightedEdge) -> Bool {
        return edges[edge.u].contains(edge)
    }

    // MARK: Implement Printable protocol
    public var description: String {
        var d: String = ""
        for i in 0..<vertices.count {
            d += "\(vertices[i]) -> \(neighborsForIndex(i))\n"
        }
        return d
    }

    // MARK: Implement CollectionType

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return vertexCount
    }

    public func index(after i: Int) -> Int {
        return i + 1
    }

    /// The same as vertexAtIndex() - returns the vertex at index
    ///
    ///
    /// - Parameter index: The index of vertex to return.
    /// - returns: The vertex at index.
    public subscript(i: Int) -> V {
        return vertexAtIndex(i)
    }

    // Based on an algorithm developed by Hongbo Liu and Jiaxin Wang
    // Liu, Hongbo, and Jiaxin Wang. "A new way to enumerate cycles in graph."
    // In Telecommunications, 2006. AICT-ICIW'06. International Conference on Internet and
    // Web Applications and Services/Advanced International Conference on, pp. 57-57. IEEE, 2006.

    /// Find all of the cycles in a `Graph`, expressed as vertices.
    ///
    /// - parameter upToLength: Does the caller only want to detect cycles up to a certain length?
    /// - returns: a list of lists of vertices in cycles
    public func detectCycles(upToLength maxK: Int = Int.max) -> [[V]] {
        var cycles = [[V]]() // store of all found cycles
        var openPaths: [[V]] = vertices.map{ [$0] } // initial open paths are single vertex lists

        while openPaths.count > 0 {
            let openPath = openPaths.removeFirst() // queue pop()
            if openPath.count > maxK { return cycles } // do we want to stop at a certain length k
            if let tail = openPath.last, let head = openPath.first, let neighbors = neighborsForVertex(tail) {
                for neighbor in neighbors {
                    if neighbor == head {
                        cycles.append(openPath + [neighbor]) // found a cycle
                    } else if !openPath.contains(neighbor) && indexOfVertex(neighbor)! > indexOfVertex(head)! {
                        openPaths.append(openPath + [neighbor]) // another open path to explore
                    }
                }
            }
        }

        return cycles
    }

    // Based on Introduction to Algorithms, 3rd Edition, Cormen et. al.,
    // The MIT Press, 2009, pg 604-614
    // and revised pseudocode of the same from Wikipedia
    // https://en.wikipedia.org/wiki/Topological_sorting#Depth-first_search

    /// Topologically sorts a `Graph` O(n)
    ///
    /// - returns: the sorted vertices, or nil if the graph cannot be sorted due to not being a DAG
    public func topologicalSort() -> [V]? {
        var sortedVertices = [V]()
        let rangeOfVertices = 0..<vertexCount
        let tsNodes = rangeOfVertices.map { TSNode(index: $0, color: .white) }
        var notDAG = false

        // Determine vertex neighbors in advance, so we have to do it once for each node.
        let neighbors: [Set<Int>] = rangeOfVertices.map({ index in
            Set(edges[index].map({ $0.v }))
        })

        func visit(_ node: TSNode) {
            guard node.color != .gray else {
                notDAG = true
                return
            }
            if node.color == .white {
                node.color = .gray
                for inode in tsNodes where neighbors[node.index].contains(inode.index) {
                    visit(inode)
                }
                node.color = .black
                sortedVertices.insert(vertices[node.index], at: 0)
            }
        }

        for node in tsNodes where node.color == .white {
            visit(node)
        }

        if notDAG {
            return nil
        }

        return sortedVertices
    }


    /// Is the `Graph` a directed-acyclic graph (DAG)? O(n)
    /// Finds the answer based on the result of a topological sort.
    var isDAG: Bool {
        guard let _ = topologicalSort() else { return false }
        return true
    }
}

private enum TSColor { case black, gray, white }
private class TSNode {
    fileprivate let index: Int
    fileprivate var color: TSColor

    init(index: Int, color: TSColor) {
        self.index = index
        self.color = color
    }
}

extension UnweightedGraph: Decodable where V: Decodable {
}

extension UnweightedGraph: Encodable where V: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: Keys.self)
        try container.encode(vertices, forKey: Keys.vertices)
        try container.encode(edges, forKey: Keys.edges)
    }
}
