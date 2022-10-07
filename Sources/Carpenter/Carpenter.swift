import Foundation
import SwiftGraph

public struct Carpenter {

    typealias Vertex = String

    var builderRegistry: [Vertex: (Any) async throws -> Any] = [:]
    var builtProductsRegistry: [Vertex: Any] = [:]
    var dependencyGraph: UnweightedGraph<Vertex> = .init()

    var indexByVertex: [Vertex: Int] = [:]

    private var requirementsByResultName: [Vertex: [Vertex]] = [:]

    public init() {}

    mutating func add<Requirement, Product>(
        _ builder: @escaping (Requirement) async throws -> Product
    ) throws {
        let requirementName = String(describing: Requirement.self)
        let resultName = String(describing: Product.self)

        guard !indexByVertex.keys.contains(resultName)
        else { throw Errors.dependencyIsAlreadyAdded(name: resultName) }

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
                throw Errors.requirementHasMismatchingType(
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
            else { throw Errors.requirementNotFound(name: String(productName)) }

            for requirement in requirementsNames {
                guard let requirementIndex = indexByVertex[String(requirement)]
                else { throw Errors.requirementNotFound(name: String(requirement)) }

                dependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }
    }

    mutating func build() async throws {
        try finalizeGraph()

        guard let sortedVertices = dependencyGraph.topologicalSort()
        else {
            let cycles = dependencyGraph.detectCycles()
            let cyclesDescription = cycles
                .map { cycle in cycle.joined(separator: " -> ") }
                .joined(separator: "\n")
            throw Errors.dependencyCycleDetected(message: cyclesDescription)
        }

        for vertex in sortedVertices {
            guard let requirements = requirementsByResultName[vertex]
            else { throw Errors.cannotRetrieveRequirementsForProduct(name: vertex) }

            guard let builder = builderRegistry[vertex]
            else { throw Errors.cannotRetrieveBuilderForProduct(name: vertex) }

            let result: Any

            switch requirements.count {
            case 0:
                result = try await builder(())

            case 1:
                guard let dependency = builtProductsRegistry[requirements[0]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[0]) }
                result = try await builder(dependency)

            case 2:
                guard let dependency1 = builtProductsRegistry[requirements[0]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[0]) }
                guard let dependency2 = builtProductsRegistry[requirements[1]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[1]) }
                result = try await builder((dependency1, dependency2))

            case 3:
                guard let dependency1 = builtProductsRegistry[requirements[0]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[0]) }
                guard let dependency2 = builtProductsRegistry[requirements[1]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[1]) }
                guard let dependency3 = builtProductsRegistry[requirements[2]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[2]) }
                result = try await builder((dependency1, dependency2, dependency3))

            case 4:
                guard let dependency1 = builtProductsRegistry[requirements[0]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[0]) }
                guard let dependency2 = builtProductsRegistry[requirements[1]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[1]) }
                guard let dependency3 = builtProductsRegistry[requirements[2]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[2]) }
                guard let dependency4 = builtProductsRegistry[requirements[3]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[3]) }
                result = try await builder((dependency1, dependency2, dependency3, dependency4))

            case 5:
                guard let dependency1 = builtProductsRegistry[requirements[0]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[0]) }
                guard let dependency2 = builtProductsRegistry[requirements[1]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[1]) }
                guard let dependency3 = builtProductsRegistry[requirements[2]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[2]) }
                guard let dependency4 = builtProductsRegistry[requirements[3]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[3]) }
                guard let dependency5 = builtProductsRegistry[requirements[4]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[4]) }
                result = try await builder((dependency1, dependency2, dependency3, dependency4, dependency5))

            case 6:
                guard let dependency1 = builtProductsRegistry[requirements[0]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[0]) }
                guard let dependency2 = builtProductsRegistry[requirements[1]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[1]) }
                guard let dependency3 = builtProductsRegistry[requirements[2]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[2]) }
                guard let dependency4 = builtProductsRegistry[requirements[3]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[3]) }
                guard let dependency5 = builtProductsRegistry[requirements[4]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[4]) }
                guard let dependency6 = builtProductsRegistry[requirements[5]]
                else { throw Errors.builtProductNotFoundForVertex(name: requirements[5]) }
                result = try await builder((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6))

            default:
                throw Errors.dependencyBuilderHasTooManyArguments(count: requirements.count)
            }

            self.builtProductsRegistry[vertex] = result
        }
    }

    func get<T>(_ builtProduct: T.Type = T.self) throws -> T {
        let name = String(describing: builtProduct)

        guard let result = self.builtProductsRegistry[name]
        else { throw Errors.productNotFound(name: name) }

        guard let typedResult = result as? T
        else { throw Errors.productHasMismatchingType(name: name, type: String(describing: type(of: result))) }

        return typedResult
    }


    enum Errors: Error {
        case requirementNotFound(name: String)
        case requirementHasMismatchingType(resultName: String, expected: String, type: String)
        case cannotRetrieveRequirementsForProduct(name: String)
        case cannotRetrieveBuilderForProduct(name: String)
        case productNotFound(name: String)
        case productHasMismatchingType(name: String, type: String)
        case dependencyIsAlreadyAdded(name: String)
        case dependencyCycleDetected(message: String)
        case builtProductNotFoundForVertex(name: String)
        case dependencyBuilderHasTooManyArguments(count: Int)
    }
}


struct DependencyNode: Equatable, Codable {
    let name: String
}
