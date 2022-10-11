import SwiftGraph

protocol DependencyKey {
    var name: String { get }
}

public struct Carpenter {

    public static var shared: Carpenter = .init()

    public typealias Vertex = String
    private typealias E = CarpenterError

    public private(set) var dependencyGraph: UnweightedGraph<Vertex> = .init()
    public private(set) var lateInitDependencyGraph: UnweightedGraph<Vertex> = .init()
    private var factoryRegistry: [Vertex: AnyFactory] = [:]
    private var builtProductsRegistry: [Vertex: Any] = [:]
    private var requirementsByResultName: [Vertex: [Vertex]] = [:]
    private var lateRequirementsByResultName: [Vertex: [Vertex]] = [:]
    private var didBuildInitialGraph = false

    // MARK: - Public

    public init() {}

    public init(@FactoryBuilder _ factoryBuilder: () -> Result<Carpenter, Error>) throws {
        self = try factoryBuilder().get()
    }

    public mutating func add(
        _ factory: some FactoryConvertible
    ) throws {
        try self.add(factory.eraseToAnyFactory())
    }

    public mutating func build() async throws {
        try finalizeGraph()

        guard let sortedVertices = dependencyGraph.topologicalSort()
        else { throw E.dependencyCyclesDetected(cycles: dependencyGraph.detectCycles()) }

        for vertex in sortedVertices where !builtProductsRegistry.keys.contains(vertex) {
            self.builtProductsRegistry[vertex] = try await self.build(vertex)
        }

        try await executeLateInitialization()
    }

    public func get<Requirement, LateInit, Product>(
        _ dependency: Factory<Requirement, LateInit, Product>
    ) throws -> Product {
        let name = String(describing: Product.self)

        guard let result = self.builtProductsRegistry[name]
        else { throw E.productNotFound(name: name) }

        guard let typedResult = result as? Product
        else { throw E.productHasMismatchingType(name: name, type: String(describing: type(of: result))) }

        return typedResult
    }

    // MARK: - Internal / Private

    mutating func add(
        _ factory: AnyFactory
    ) throws {
        guard !requirementsByResultName.keys.contains(factory.resultName)
        else { throw E.factoryAlreadyAdded(name: factory.resultName) }

        guard !lateRequirementsByResultName.keys.contains(factory.resultName)
        else { throw E.factoryAlreadyAdded(name: factory.resultName) }

        requirementsByResultName[factory.resultName] = splitRequirements(factory.requirementName)
        lateRequirementsByResultName[factory.resultName] = splitRequirements(factory.lateRequirementName)

        _ = dependencyGraph.addVertex(factory.resultName)
        _ = lateInitDependencyGraph.addVertex(factory.resultName)

        factoryRegistry[factory.resultName] = factory
    }

    private func build(
        _ vertex: String
    ) async throws -> Any {
        guard let requirements = requirementsByResultName[vertex]
        else { throw E.cannotRetrieveRequirementsForProduct(name: vertex) }

        guard let factory = factoryRegistry[vertex]?.builder
        else { throw E.cannotRetrieveFactoryBuilder(name: vertex) }

        let result: Any

        // TODO: Apply variadic generics once available

        switch requirements.count {
        case 0:
            result = try await factory(())

        case 1:
            guard let dependency = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            result = try await factory(dependency)

        case 2:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            result = try await factory((dependency1, dependency2))

        case 3:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            result = try await factory((dependency1, dependency2, dependency3))

        case 4:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            guard let dependency4 = builtProductsRegistry[requirements[3]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[3]) }
            result = try await factory((dependency1, dependency2, dependency3, dependency4))

        case 5:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            guard let dependency4 = builtProductsRegistry[requirements[3]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[3]) }
            guard let dependency5 = builtProductsRegistry[requirements[4]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[4]) }
            result = try await factory((dependency1, dependency2, dependency3, dependency4, dependency5))

        case 6:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            guard let dependency4 = builtProductsRegistry[requirements[3]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[3]) }
            guard let dependency5 = builtProductsRegistry[requirements[4]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[4]) }
            guard let dependency6 = builtProductsRegistry[requirements[5]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[5]) }
            result = try await factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6))

        default:
            throw E.factoryBuilderHasTooManyArguments(name: vertex, count: requirements.count)
        }

        return result
    }

    private mutating func executeLateInitialization() async throws {
        guard let sortedVertices = lateInitDependencyGraph.topologicalSort()
        else { throw E.lateInitCyclesDetected(cycles: lateInitDependencyGraph.detectCycles()) }

        for vertex in sortedVertices {
            self.builtProductsRegistry[vertex] = try await self.lateInitialize(vertex)
        }
    }

    private func lateInitialize(_ vertex: String) async throws -> Any {
        guard var product = builtProductsRegistry[vertex]
        else { throw E.builtProductNotFoundForVertex(name: vertex) }

        guard let requirements = lateRequirementsByResultName[vertex]
        else { throw E.cannotRetrieveLateRequirementsForProduct(name: vertex) }

        guard let setup = factoryRegistry[vertex]?.lateInit
        else { throw E.cannotRetrieveFactoryLateInitialization(name: vertex) }

        // TODO: Apply variadic generics once available

        switch requirements.count {
        case 0:
            try await setup(&product, ())

        case 1:
            guard let dependency = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            try await setup(&product, dependency)

        case 2:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            try await setup(&product, (dependency1, dependency2))

        case 3:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            try await setup(&product, (dependency1, dependency2, dependency3))

        case 4:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            guard let dependency4 = builtProductsRegistry[requirements[3]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[3]) }
            try await setup(&product, (dependency1, dependency2, dependency3, dependency4))

        case 5:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            guard let dependency4 = builtProductsRegistry[requirements[3]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[3]) }
            guard let dependency5 = builtProductsRegistry[requirements[4]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[4]) }
            try await setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5))

        case 6:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            guard let dependency4 = builtProductsRegistry[requirements[3]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[3]) }
            guard let dependency5 = builtProductsRegistry[requirements[4]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[4]) }
            guard let dependency6 = builtProductsRegistry[requirements[5]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[5]) }
            try await setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6))

        default:
            throw E.factoryLateInitHasTooManyArguments(name: vertex, count: requirements.count)
        }

        return product
    }

    mutating func finalizeGraph() throws {
        for index in dependencyGraph.edges.indices {
            dependencyGraph.edges[index].removeAll()
        }
        for index in lateInitDependencyGraph.edges.indices {
            lateInitDependencyGraph.edges[index].removeAll()
        }

        for (productName, requirementsNames) in requirementsByResultName {
            guard let productIndex = dependencyGraph.indexOfVertex(productName)
            else { throw E.productNotFound(name: String(productName)) }

            for requirement in requirementsNames {
                guard let requirementIndex = dependencyGraph.indexOfVertex(requirement)
                else { throw E.requirementNotFound(name: String(requirement)) }

                dependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }

        for (productName, requirementsNames) in lateRequirementsByResultName {
            guard let productIndex = lateInitDependencyGraph.indexOfVertex(productName)
            else { throw E.productNotFoundForLateInitialization(name: String(productName)) }

            for requirement in requirementsNames {
                guard let requirementIndex = lateInitDependencyGraph.indexOfVertex(requirement)
                else { throw E.requirementNotFoundForLateInitialization(name: String(requirement)) }

                lateInitDependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }
    }
}

private func splitRequirements(_ requirementName: String) -> [String] {
    if requirementName != String(describing: Void.self) {
        let requirements = requirementName.trimmingCharacters(in: .init(["(", ")"]))

        return requirements
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
    } else {
        return []
    }
}

public enum CarpenterError: Error, Equatable, CustomStringConvertible {
    case requirementNotFound(name: String)
    case requirementNotFoundForLateInitialization(name: String)
    case requirementHasMismatchingType(resultName: String, expected: String, type: String)
    case lateRequirementHasMismatchingType(resultName: String, expected: String, type: String)
    case cannotRetrieveRequirementsForProduct(name: String)
    case cannotRetrieveLateRequirementsForProduct(name: String)
    case cannotRetrieveFactoryBuilder(name: String)
    case cannotRetrieveFactoryLateInitialization(name: String)
    case productNotFound(name: String)
    case productNotFoundForLateInitialization(name: String)
    case productHasMismatchingType(name: String, type: String)
    case factoryAlreadyAdded(name: String)
    case builtProductNotFoundForVertex(name: String)
    case factoryBuilderHasTooManyArguments(name: String, count: Int)
    case factoryLateInitHasTooManyArguments(name: String, count: Int)
    case dependencyCyclesDetected(cycles: [[String]])
    case lateInitCyclesDetected(cycles: [[String]])

    public var description: String {
        switch self {
        case let .requirementNotFound(name):
            return "Requirement \"\(name)\" not found in builder graph."
        case let .requirementNotFoundForLateInitialization(name):
            return "Requirement \"\(name)\" not found in late initialization graph."
        case let .requirementHasMismatchingType(resultName, expected, type):
            return "Requirement for product \"\(resultName)\" has wrong type: expected \"\(expected)\", found \"\(type)\"."
        case let .lateRequirementHasMismatchingType(resultName, expected, type):
            return "Late init requirement for product \"\(resultName)\" has wrong type: expected \"\(expected)\", found \"\(type)\"."
        case let .cannotRetrieveRequirementsForProduct(name):
            return "Cannot retrieve requirements for product \"\(name)\"."
        case let .cannotRetrieveLateRequirementsForProduct(name):
            return "Cannot retrieve late requirements for product \"\(name)\"."
        case let .cannotRetrieveFactoryBuilder(name):
            return "Cannot retrieve builder for product \"\(name)\" in builder graph."
        case let .cannotRetrieveFactoryLateInitialization(name):
            return "Cannot retrieve builder for product \"\(name)\" in late initialization graph."
        case let .productNotFound(name):
            return "Product \"\(name)\" not found in builder graph."
        case let .productNotFoundForLateInitialization(name):
            return "Product \"\(name)\" not found in late initialization graph."
        case let .productHasMismatchingType(name, type):
            return "Product \"\(name)\" has mismatching type \"\(type)\"."
        case let .factoryAlreadyAdded(name):
            return "Already added builder for product \"\(name)\"."
        case let .builtProductNotFoundForVertex(name):
            return "Built product not found for product \"\(name)\"."
        case let .factoryBuilderHasTooManyArguments(name, count):
            return "Dependency builder for \"\(name)\" has too many arguments (\(count))."
        case let .factoryLateInitHasTooManyArguments(name, count):
            return "Dependency late initialization for \"\(name)\" has too many arguments (\(count))."
        case let .dependencyCyclesDetected(cycles):
            return """
            Cycles detected in dependency graph:
            \(cycles.reversed().map { $0.joined(separator: " -> ") }.joined(separator: "\n"))
            """
        case let .lateInitCyclesDetected(cycles):
            return """
            Cycles detected in late initialization graph:
            \(cycles.reversed().map { $0.joined(separator: " -> ") }.joined(separator: "\n"))
            """
        }
    }
}
