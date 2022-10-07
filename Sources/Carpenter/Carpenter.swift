import Foundation
import SwiftGraph

public struct Factory<Requirement, Product> {
    public var wrappedValue: (Requirement) async throws -> Product

    public init(_ builder: @escaping (Requirement) async throws -> Product) {
        self.wrappedValue = builder
    }

    public func callAsFunction(_ requirement: Requirement) async throws -> Product {
        try await wrappedValue(requirement)
    }
}

public struct Carpenter {

    typealias Vertex = String
    private typealias E = CarpenterError

    var dependencyGraph: UnweightedGraph<Vertex> = .init()
    var lateInitDependencyGraph: UnweightedGraph<Vertex> = .init()
    private var factoryRegistry: [Vertex: (Any) async throws -> Any] = [:]
    private var lateInitRegistry: [Vertex: (inout Any, Any) async throws -> Void] = [:]
    private var builtProductsRegistry: [Vertex: Any] = [:]
    private var indexByVertexForDependencies: [Vertex: Int] = [:]
    private var indexByVertexForLateInit: [Vertex: Int] = [:]
    private var requirementsByResultName: [Vertex: [Vertex]] = [:]
    private var lateRequirementsByResultName: [Vertex: [Vertex]] = [:]

    public init() {}

    public mutating func add<Requirement, LateRequirement, Product>(
        _ factory: Factory<Requirement, Product>,
        lateInit: @escaping (inout Product, LateRequirement) async throws -> Void
    ) throws {
        let requirementName = String(describing: Requirement.self)
        let lateRequirementName = String(describing: LateRequirement.self)
        let resultName = String(describing: Product.self)

        guard !indexByVertexForDependencies.keys.contains(resultName)
        else { throw E.dependencyIsAlreadyAdded(name: resultName) }

        guard !lateRequirementsByResultName.keys.contains(resultName)
        else { throw E.dependencyIsAlreadyAdded(name: resultName) }

        indexByVertexForDependencies[resultName] = dependencyGraph.addVertex(resultName)
        indexByVertexForLateInit[resultName] = lateInitDependencyGraph.addVertex(resultName)

        requirementsByResultName[resultName] = splitRequirements(requirementName)
        lateRequirementsByResultName[resultName] = splitRequirements(lateRequirementName)

        factoryRegistry[resultName] = {
            guard let requirement = $0 as? Requirement
            else {
                throw E.requirementHasMismatchingType(
                    resultName: resultName,
                    expected: String(describing: Requirement.self),
                    type: String(describing: type(of: $0)))
            }

            return try await factory(requirement)
        }

        lateInitRegistry[resultName] = {
            guard var product = $0 as? Product
            else {
                throw E.productHasMismatchingType(
                    name: resultName,
                    type: String(describing: type(of: $0)))
            }

            guard let requirement = $1 as? LateRequirement
            else {
                throw E.lateRequirementHasMismatchingType(
                    resultName: resultName,
                    expected: String(describing: Requirement.self),
                    type: String(describing: type(of: $0)))
            }

            try await lateInit(&product, requirement)
            $0 = product
        }
    }

    public mutating func add<Requirement, Product>(
        _ factory: Factory<Requirement, Product>,
        lateInit: @escaping (inout Product) async throws -> Void
    ) throws {
        try self.add(
            factory,
            lateInit: { (x, _: Void) in try await lateInit(&x) })
    }

    public mutating func add<Requirement, Product>(
        _ factory: Factory<Requirement, Product>
    ) throws {
        try self.add(
            factory,
            lateInit: { (_, _: Void) in })
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

    mutating func finalizeGraph() throws {
        guard dependencyGraph.edgeCount == 0 else { return }

        for (productName, requirementsNames) in requirementsByResultName {
            guard let productIndex = indexByVertexForDependencies[String(productName)]
            else { throw E.requirementNotFound(name: String(productName)) }

            for requirement in requirementsNames {
                guard let requirementIndex = indexByVertexForDependencies[String(requirement)]
                else { throw E.requirementNotFound(name: String(requirement)) }

                dependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }

        for (productName, requirementsNames) in lateRequirementsByResultName {
            guard let productIndex = indexByVertexForLateInit[String(productName)]
            else { throw E.requirementNotFound(name: String(productName)) }

            for requirement in requirementsNames {
                guard let requirementIndex = indexByVertexForLateInit[String(requirement)]
                else { throw E.requirementNotFound(name: String(requirement)) }

                lateInitDependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }
    }

    public mutating func build() async throws {
        try finalizeGraph()

        guard let sortedVertices = dependencyGraph.topologicalSort()
        else { throw E.dependencyCyclesDetected(cycles: dependencyGraph.detectCycles()) }

        for vertex in sortedVertices {
            guard let requirements = requirementsByResultName[vertex]
            else { throw E.cannotRetrieveRequirementsForProduct(name: vertex) }

            guard let factory = factoryRegistry[vertex]
            else { throw E.cannotRetrieveFactoryForProduct(name: vertex) }

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
                throw E.factoryHasTooManyArguments(count: requirements.count)
            }

            self.builtProductsRegistry[vertex] = result
        }

        try await executeLateInitialization()
    }

    private mutating func executeLateInitialization() async throws {
        guard let sortedVertices = lateInitDependencyGraph.topologicalSort()
        else { throw E.lateInitCyclesDetected(cycles: lateInitDependencyGraph.detectCycles()) }

        for vertex in sortedVertices {
            guard var product = builtProductsRegistry[vertex]
            else { throw E.builtProductNotFoundForVertex(name: vertex) }

            guard let requirements = lateRequirementsByResultName[vertex]
            else { throw E.cannotRetrieveLateRequirementsForProduct(name: vertex) }

            guard let setup = lateInitRegistry[vertex]
            else { throw E.cannotRetrieveFactoryForProduct(name: vertex) }

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
                throw E.factoryHasTooManyArguments(count: requirements.count)
            }

            self.builtProductsRegistry[vertex] = product
        }
    }

    public func get<R, Product>(_ dependency: Factory<R, Product>) throws -> Product {
        let name = String(describing: Product.self)

        guard let result = self.builtProductsRegistry[name]
        else { throw E.productNotFound(name: name) }

        guard let typedResult = result as? Product
        else { throw E.productHasMismatchingType(name: name, type: String(describing: type(of: result))) }

        return typedResult
    }
}

public enum CarpenterError: CustomNSError, Equatable {
    case requirementNotFound(name: String)
    case requirementHasMismatchingType(resultName: String, expected: String, type: String)
    case lateRequirementHasMismatchingType(resultName: String, expected: String, type: String)
    case cannotRetrieveRequirementsForProduct(name: String)
    case cannotRetrieveLateRequirementsForProduct(name: String)
    case cannotRetrieveFactoryForProduct(name: String)
    case productNotFound(name: String)
    case productHasMismatchingType(name: String, type: String)
    case dependencyIsAlreadyAdded(name: String)
    case builtProductNotFoundForVertex(name: String)
    case factoryHasTooManyArguments(count: Int)
    case dependencyCyclesDetected(cycles: [[String]])
    case lateInitCyclesDetected(cycles: [[String]])

    public static let errorDomain: String = "com.ticketswap.carpenter"

    public var errorCode: Int {
        switch self {
        case .requirementNotFound: return 1
        case .requirementHasMismatchingType: return 2
        case .cannotRetrieveRequirementsForProduct: return 3
        case .cannotRetrieveFactoryForProduct: return 4
        case .productNotFound: return 5
        case .productHasMismatchingType: return 6
        case .dependencyIsAlreadyAdded: return 7
        case .builtProductNotFoundForVertex: return 8
        case .factoryHasTooManyArguments: return 9
        case .cannotRetrieveLateRequirementsForProduct: return 10
        case .lateRequirementHasMismatchingType: return 11
        case .dependencyCyclesDetected: return 12
        case .lateInitCyclesDetected: return 13
        }
    }

    public var errorUserInfo: [String : Any] {
        switch self {
        case let .requirementNotFound(name): return [
            NSLocalizedDescriptionKey: "Requirement \"\(name)\" not found."
        ]
        case let .requirementHasMismatchingType(resultName, expected, type): return [
            NSLocalizedDescriptionKey: "Requirement for product \"\(resultName)\" has wrong type: expected \"\(expected)\", found \"\(type)\"."
        ]
        case let .lateRequirementHasMismatchingType(resultName, expected, type): return [
            NSLocalizedDescriptionKey: "Late init requirement for product \"\(resultName)\" has wrong type: expected \"\(expected)\", found \"\(type)\"."
        ]
        case let .cannotRetrieveRequirementsForProduct(name): return [
            NSLocalizedDescriptionKey: "Cannot retrieve requirements for product \"\(name)\"."
        ]
        case let .cannotRetrieveLateRequirementsForProduct(name): return [
            NSLocalizedDescriptionKey: "Cannot retrieve late requirements for product \"\(name)\"."
        ]
        case let .cannotRetrieveFactoryForProduct(name): return [
            NSLocalizedDescriptionKey: "Cannot retrieve builder for product \"\(name)\"."
        ]
        case let .productNotFound(name): return [
            NSLocalizedDescriptionKey: "Product \"\(name)\" not found."
        ]
        case let .productHasMismatchingType(name, type): return [
            NSLocalizedDescriptionKey: "Product \"\(name)\" has mismatching type \"\(type)\"."
        ]
        case let .dependencyIsAlreadyAdded(name): return [
            NSLocalizedDescriptionKey: "Already added builder for product \"\(name)\"."
        ]
        case let .builtProductNotFoundForVertex(name): return [
            NSLocalizedDescriptionKey: "Built product not found for product \"\(name)\"."
        ]
        case let .factoryHasTooManyArguments(count): return [
            NSLocalizedDescriptionKey: "Dependency builder has too many arguments (\(count))."
        ]
        case let .dependencyCyclesDetected(cycles): return [
            NSLocalizedDescriptionKey: """
            Cycles detected in dependency graph:
            \(cycles.reversed().map { $0.joined(separator: " -> ") }.joined(separator: "\n"))
            """
        ]
        case let .lateInitCyclesDetected(cycles): return [
            NSLocalizedDescriptionKey: """
            Cycles detected in late initialization graph:
            \(cycles.reversed().map { $0.joined(separator: " -> ") }.joined(separator: "\n"))
            """
        ]
        }
    }
}
