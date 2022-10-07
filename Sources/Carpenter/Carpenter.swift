import Foundation
import SwiftGraph

public struct Carpenter {

    typealias Vertex = String
    private typealias E = CarpenterError

    var dependencyGraph: UnweightedGraph<Vertex> = .init()
    private var builderRegistry: [Vertex: (Any) async throws -> Any] = [:]
    private var builtProductsRegistry: [Vertex: Any] = [:]
    private var indexByVertex: [Vertex: Int] = [:]
    private var requirementsByResultName: [Vertex: [Vertex]] = [:]

    public init() {}

    public mutating func add<Requirement, Product>(
        _ builder: @escaping (Requirement) async throws -> Product
    ) throws {
        let requirementName = String(describing: Requirement.self)
        let resultName = String(describing: Product.self)

        guard !indexByVertex.keys.contains(resultName)
        else { throw E.dependencyIsAlreadyAdded(name: resultName) }

        let newVertexIndex = dependencyGraph.addVertex(resultName)
        indexByVertex[resultName] = newVertexIndex

        if requirementName != String(describing: Void.self) {
            let requirements = requirementName.trimmingCharacters(in: .init(["(", ")"]))

            requirementsByResultName[resultName] = requirements
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        } else {
            requirementsByResultName[resultName] = []
        }

        builderRegistry[resultName] = {
            guard let requirement = $0 as? Requirement
            else {
                throw E.requirementHasMismatchingType(
                    resultName: resultName,
                    expected: String(describing: Requirement.self),
                    type: String(describing: type(of: $0)))
            }

            return try await builder(requirement)
        }
    }

    mutating func finalizeGraph() throws {
        guard dependencyGraph.edgeCount == 0 else { return }

        for (productName, requirementsNames) in requirementsByResultName {
            guard let productIndex = indexByVertex[String(productName)]
            else { throw E.requirementNotFound(name: String(productName)) }

            for requirement in requirementsNames {
                guard let requirementIndex = indexByVertex[String(requirement)]
                else { throw E.requirementNotFound(name: String(requirement)) }

                dependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }
    }

    public mutating func build() async throws {
        try finalizeGraph()

        // There cannot be cycles, because we cannot add two builders that produce the same result.
        let sortedVertices = dependencyGraph.topologicalSort()!

        for vertex in sortedVertices {
            guard let requirements = requirementsByResultName[vertex]
            else { throw E.cannotRetrieveRequirementsForProduct(name: vertex) }

            guard let builder = builderRegistry[vertex]
            else { throw E.cannotRetrieveBuilderForProduct(name: vertex) }

            let result: Any

            switch requirements.count {
            case 0:
                result = try await builder(())

            case 1:
                guard let dependency = builtProductsRegistry[requirements[0]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
                result = try await builder(dependency)

            case 2:
                guard let dependency1 = builtProductsRegistry[requirements[0]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
                guard let dependency2 = builtProductsRegistry[requirements[1]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
                result = try await builder((dependency1, dependency2))

            case 3:
                guard let dependency1 = builtProductsRegistry[requirements[0]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
                guard let dependency2 = builtProductsRegistry[requirements[1]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
                guard let dependency3 = builtProductsRegistry[requirements[2]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
                result = try await builder((dependency1, dependency2, dependency3))

            case 4:
                guard let dependency1 = builtProductsRegistry[requirements[0]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
                guard let dependency2 = builtProductsRegistry[requirements[1]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
                guard let dependency3 = builtProductsRegistry[requirements[2]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
                guard let dependency4 = builtProductsRegistry[requirements[3]]
                else { throw E.builtProductNotFoundForVertex(name: requirements[3]) }
                result = try await builder((dependency1, dependency2, dependency3, dependency4))

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
                result = try await builder((dependency1, dependency2, dependency3, dependency4, dependency5))

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
                result = try await builder((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6))

            default:
                throw E.dependencyBuilderHasTooManyArguments(count: requirements.count)
            }

            self.builtProductsRegistry[vertex] = result
        }
    }

    public func get<T>(_ builtProduct: T.Type = T.self) throws -> T {
        let name = String(describing: builtProduct)

        guard let result = self.builtProductsRegistry[name]
        else { throw E.productNotFound(name: name) }

        guard let typedResult = result as? T
        else { throw E.productHasMismatchingType(name: name, type: String(describing: type(of: result))) }

        return typedResult
    }
}

public enum CarpenterError: CustomNSError, Equatable {
    case requirementNotFound(name: String)
    case requirementHasMismatchingType(resultName: String, expected: String, type: String)
    case cannotRetrieveRequirementsForProduct(name: String)
    case cannotRetrieveBuilderForProduct(name: String)
    case productNotFound(name: String)
    case productHasMismatchingType(name: String, type: String)
    case dependencyIsAlreadyAdded(name: String)
    case builtProductNotFoundForVertex(name: String)
    case dependencyBuilderHasTooManyArguments(count: Int)

    public static let errorDomain: String = "com.ticketswap.carpenter"

    public var errorCode: Int {
        switch self {
        case .requirementNotFound: return 1
        case .requirementHasMismatchingType: return 2
        case .cannotRetrieveRequirementsForProduct: return 3
        case .cannotRetrieveBuilderForProduct: return 4
        case .productNotFound: return 5
        case .productHasMismatchingType: return 6
        case .dependencyIsAlreadyAdded: return 7
        case .builtProductNotFoundForVertex: return 8
        case .dependencyBuilderHasTooManyArguments: return 9
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
        case let .cannotRetrieveRequirementsForProduct(name): return [
            NSLocalizedDescriptionKey: "Cannot retrieve requirements for product \"\(name)\"."
        ]
        case let .cannotRetrieveBuilderForProduct(name): return [
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
        case let .dependencyBuilderHasTooManyArguments(count): return [
            NSLocalizedDescriptionKey: "Dependency builder has too many arguments (\(count))."
        ]
        }
    }
}
