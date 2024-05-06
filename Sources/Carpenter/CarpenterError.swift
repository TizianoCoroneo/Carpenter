
public enum CarpenterError: Error, Equatable, CustomStringConvertible {
    case requirementNotFound(name: Vertex, requestedBy: Vertex)
    case requirementNotFoundForLateInitialization(name: Vertex, requestedBy: Vertex)
    case requirementHasMismatchingType(resultName: Vertex, expected: [Vertex], type: Vertex)
    case lateRequirementHasMismatchingType(resultName: Vertex, expected: [Vertex], type: Vertex)
    case cannotRetrieveRequirementsForProduct(name: Vertex)
    case cannotRetrieveLateRequirementsForProduct(name: Vertex)
    case cannotRetrieveFactoryBuilder(name: Vertex)
    case cannotRetrieveFactoryLateInitialization(name: Vertex)
    case productNotFound(name: Vertex)
    case productNotFoundForLateInitialization(name: Vertex)
    case productHasMismatchingType(name: Vertex, type: Vertex)
    case factoryAlreadyAdded(name: Vertex)
    case cannotAddLateInitWithoutFactory(name: Vertex)
    case builtProductNotFoundForVertex(name: Vertex)
    case factoryBuilderHasTooManyArguments(name: Vertex, count: Int)
    case factoryLateInitHasTooManyArguments(name: Vertex, count: Int)
    case dependencyCyclesDetected(cycles: [[Vertex]])
    case lateInitCyclesDetected(cycles: [[Vertex]])

    public var description: String {
        switch self {
        case let .requirementNotFound(name, requestedBy):
            return "Requirement \"\(name)\" not found in builder graph; requested by \(requestedBy)."
        case let .requirementNotFoundForLateInitialization(name, requestedBy):
            return "Requirement \"\(name)\" not found in late initialization graph; requested by \(requestedBy)."
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
        case let .cannotAddLateInitWithoutFactory(name):
            return "Cannot add a `LateInit` for class: \"\(name)\" has no `Factory`."
        case let .builtProductNotFoundForVertex(name):
            return "Built product not found for product \"\(name)\"."
        case let .factoryBuilderHasTooManyArguments(name, count):
            return "Dependency builder for \"\(name)\" has too many arguments (\(count))."
        case let .factoryLateInitHasTooManyArguments(name, count):
            return "Dependency late initialization for \"\(name)\" has too many arguments (\(count))."
        case let .dependencyCyclesDetected(cycles):
            return """
            Cycles detected in dependency graph:
            \(cycles.map { $0.map { "\($0)" }.joined(separator: " -> ") }.joined(separator: "\n"))
            """
        case let .lateInitCyclesDetected(cycles):
            return """
            Cycles detected in late initialization graph:
            \(cycles.map { $0.map { "\($0)" }.joined(separator: " -> ") }.joined(separator: "\n"))
            """
        }
    }
}
