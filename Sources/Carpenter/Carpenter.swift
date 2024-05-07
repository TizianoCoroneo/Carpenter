//import class SwiftGraph.UnweightedGraph
//import struct SwiftGraph.UnweightedEdge

public typealias Vertex = AnyDependencyKey

public struct Carpenter {

    public static var shared: Carpenter = .init()

    private typealias E = CarpenterError

    public private(set) var dependencyGraph: UnweightedGraph<AnyDependencyKey> = .init()
    public private(set) var lateInitDependencyGraph: UnweightedGraph<AnyDependencyKey> = .init()
    private(set) var factoryRegistry: [AnyDependencyKey: AnyFactory] = [:]
    private(set) var lateFactoryRegistry: [AnyDependencyKey: AnyFactory] = [:]
    private var builtProductsRegistry: [AnyDependencyKey: Any] = [:]
    private var requirementsByResultName: [AnyDependencyKey: ContiguousArray<AnyDependencyKey>] = [:]
    private var lateRequirementsByResultName: [AnyDependencyKey: ContiguousArray<AnyDependencyKey>] = [:]
    private var didBuildInitialGraph = false

    // MARK: - Public

    public init() {}

    public init(@FactoryBuilder _ factoryBuilder: () -> [AnyFactory]) throws {
        self.init()
        let factories = factoryBuilder()

        for factory in factories {
            try self.add(factory)
        }
    }

    public mutating func add(
        _ factory: some FactoryConvertible
    ) throws {
        for f in factory.eraseToAnyFactory() {
            try self.add(f)
        }
    }

    public mutating func add(
        @FactoryBuilder _ factories: () -> [AnyFactory]
    ) throws {
        let factories = factories()

        for factory in factories {
            try self.add(factory)
        }
    }

    public mutating func build() throws {
        try finalizeGraph()

        guard let sortedVertices = dependencyGraph.topologicalSort()
        else { throw E.dependencyCyclesDetected(cycles: dependencyGraph.detectCycles()) }

        for vertex in sortedVertices where !builtProductsRegistry.keys.contains(vertex) {
            self.builtProductsRegistry[vertex] = try self.build(vertex)
        }

        try executeLateInitialization()
    }

    public func get<Product>(
        _ dependencyKey: DependencyKey<Product>
    ) throws -> Product {
        let name = dependencyKey.eraseToAnyDependencyKey()

        guard let result = self.builtProductsRegistry[name]
        else { throw E.productNotFound(name: name) }

        guard let typedResult = result as? Product
        else { throw E.productHasMismatchingType(name: name, type: Vertex(metatype: type(of: result))) }

        return typedResult
    }

    @available(iOS 17, macOS 14, *)
    public func get<each Requirements, Product>(
        _ factory: Factory<repeat each Requirements, Product>
    ) throws -> Product {
        try self.get(DependencyKey<Product>())
    }

    // MARK: - Internal / Private

    mutating func add(
        _ factory: AnyFactory
    ) throws {
        switch factory.builder {
        case .early:
            guard !requirementsByResultName.keys.contains(factory.productName)
            else { throw E.factoryAlreadyAdded(name: factory.productName) }

            requirementsByResultName[factory.productName] = factory.requirementName
            _ = dependencyGraph.addVertex(factory.productName)
            factoryRegistry[factory.productName] = factory

        case .late:
            guard requirementsByResultName.keys.contains(factory.productName)
            else { throw E.cannotAddLateInitWithoutFactory(name: factory.productName) }
            guard !lateRequirementsByResultName.keys.contains(factory.productName)
            else { throw E.factoryAlreadyAdded(name: factory.productName) }

            lateRequirementsByResultName[factory.productName] = factory.requirementName
            _ = lateInitDependencyGraph.addVertex(factory.productName)
            lateFactoryRegistry[factory.productName] = factory
        }
    }

    private func build(
        _ vertex: Vertex
    ) throws -> Any {
        guard let requirements = requirementsByResultName[vertex]
        else { throw E.cannotRetrieveRequirementsForProduct(name: vertex) }

        guard case .early(let factory) = factoryRegistry[vertex]?.builder
        else { throw E.cannotRetrieveFactoryBuilder(name: vertex) }

        /**
         2022: Apply variadic generics once available (note from 2024: once, here there were 15 overloads for different arities of builders.
         2024: since we are going from a value (count of requirements) to a type (length of the tuple)
         variadic generics are probably not enough to solve this.
         1 day later: I also spent a lot of time trying to use various nefarious `withMemoryRebinding` hacks
         to convert between arrays and tuples, but stuff breaks after 8 elements.
         5 hours later: I finally cracked the code. Check this out:
         ```swift
        var count = 0
        func cast<R>(_ value: [Any], to r: R.Type = R.self) throws -> R {
            defer { count += 1 }
            guard let castValue = value[count] as? R else { throw /* */ }
            return castValue
        }
        let requirement = try (repeat cast(anyArray, to: (each Requirement).self))
        return try self.builder(repeat each requirement)
         ```

         This code effectively casts one element at the time from a `[Any]` into a value pack, which is then passed to a builder.
         Here we just create an array of built dependencies from the requirements, then in the resolver functions inside the conversion
         from `Factory` objects to `AnyFactory` we use the `cast` function above to convert this array of dependencies in the
         specific types required by the initializer that we are wrapping.
         */

        return try factory(requirements.map {
            guard let dependency = builtProductsRegistry[$0]
            else { throw E.builtProductNotFoundForVertex(name: $0) }
            return dependency
        })
    }

    private mutating func executeLateInitialization() throws {
        guard let sortedVertices = lateInitDependencyGraph.topologicalSort()
        else { throw E.lateInitCyclesDetected(cycles: lateInitDependencyGraph.detectCycles()) }

        for vertex in sortedVertices {
            self.builtProductsRegistry[vertex] = try self.lateInitialize(vertex)
        }
    }

    private func lateInitialize(_ vertex: Vertex) throws -> Any {
        guard var product = builtProductsRegistry[vertex]
        else { throw E.builtProductNotFoundForVertex(name: vertex) }

        guard let requirements = lateRequirementsByResultName[vertex]
        else { throw E.cannotRetrieveLateRequirementsForProduct(name: vertex) }

        guard case .late(let setup) = lateFactoryRegistry[vertex]?.builder
        else { throw E.cannotRetrieveFactoryLateInitialization(name: vertex) }

        try setup(&product, requirements.map { requirement in
            guard let dependency = builtProductsRegistry[requirement]
            else { throw E.builtProductNotFoundForVertex(name: requirement) }
            return dependency
        })

        return product
    }

    mutating func finalizeGraph() throws {
        for index in dependencyGraph.edges.indices {
            dependencyGraph.edges[index].removeAll()
        }
        for index in lateInitDependencyGraph.edges.indices {
            lateInitDependencyGraph.edges[index].removeAll()
        }

        let dependencyGraphIndexCache = [Vertex: Int](
            uniqueKeysWithValues: dependencyGraph.vertices.enumerated().map { ($1, $0) })
        let lateDependencyGraphIndexCache = [Vertex: Int](
            uniqueKeysWithValues: lateInitDependencyGraph.vertices.enumerated().map { ($1, $0) })

        for (productName, requirementsNames) in requirementsByResultName {
            guard let productIndex = dependencyGraphIndexCache[productName]
            else { throw E.productNotFound(name: productName) }

            for requirement in requirementsNames {
                guard let requirementIndex = dependencyGraphIndexCache[requirement]
                else { throw E.requirementNotFound(name: requirement, requestedBy: productName) }

                dependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }

        for (productName, requirementsNames) in lateRequirementsByResultName {
            guard let productIndex = lateDependencyGraphIndexCache[productName]
            else { throw E.productNotFoundForLateInitialization(name: productName) }

            for requirement in requirementsNames {
                guard let requirementIndex = lateDependencyGraphIndexCache[requirement]
                else { throw E.requirementNotFoundForLateInitialization(name: requirement, requestedBy: productName) }

                lateInitDependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }
    }
}
