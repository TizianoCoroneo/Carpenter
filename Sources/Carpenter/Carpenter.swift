import SwiftGraph

public struct DependencyKey<Product> {
    let name: String

    init(name: String) {
        self.name = name
    }

    public init() {
        self.init(name: String(describing: Product.self))
    }
}

public struct Carpenter {

    public static var shared: Carpenter = .init()

    public typealias Vertex = String
    private typealias E = CarpenterError

    public private(set) var dependencyGraph: UnweightedGraph<Vertex> = .init()
    public private(set) var lateInitDependencyGraph: UnweightedGraph<Vertex> = .init()
    private(set) var factoryRegistry: [Vertex: AnyFactory] = [:]
    private var builtProductsRegistry: [Vertex: Any] = [:]
    private var requirementsByResultName: [Vertex: [Vertex]] = [:]
    private var lateRequirementsByResultName: [Vertex: [Vertex]] = [:]
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
        let name = dependencyKey.name

        guard let result = self.builtProductsRegistry[name]
        else { throw E.productNotFound(name: name) }

        guard let typedResult = result as? Product
        else { throw E.productHasMismatchingType(name: name, type: String(describing: type(of: result))) }

        return typedResult
    }

    public func get<Requirements, LateRequirements, Product>(
        _ factory: Factory<Requirements, LateRequirements, Product>
    ) throws -> Product {
        try self.get(DependencyKey<Product>())
    }

    // MARK: - Internal / Private

    mutating func add(
        _ factory: AnyFactory
    ) throws {
        guard !requirementsByResultName.keys.contains(factory.productName)
        else { throw E.factoryAlreadyAdded(name: factory.productName) }

        guard !lateRequirementsByResultName.keys.contains(factory.productName)
        else { throw E.factoryAlreadyAdded(name: factory.productName) }

        requirementsByResultName[factory.productName] = splitTupleContent(factory.requirementName)
        lateRequirementsByResultName[factory.productName] = splitTupleContent(factory.lateRequirementName)

        _ = dependencyGraph.addVertex(factory.productName)
        _ = lateInitDependencyGraph.addVertex(factory.productName)

        factoryRegistry[factory.productName] = factory
    }

    private func build(
        _ vertex: String
    ) throws -> Any {
        guard let requirements = requirementsByResultName[vertex]
        else { throw E.cannotRetrieveRequirementsForProduct(name: vertex) }

        guard let factory = factoryRegistry[vertex]?.builder
        else { throw E.cannotRetrieveFactoryBuilder(name: vertex) }

        let result: Any

        // TODO: Apply variadic generics once available

        switch requirements.count {
        case 0:
            result = try factory(())

        case 1:
            guard let dependency = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            result = try factory(dependency)

        case 2:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            result = try factory((dependency1, dependency2))

        case 3:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            result = try factory((dependency1, dependency2, dependency3))

        case 4:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            guard let dependency4 = builtProductsRegistry[requirements[3]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[3]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4))

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
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5))

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
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6))

        case 7:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7))

        case 8:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8))

        case 9:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9))

        case 10:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10))

        case 11:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11))

        case 12:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            guard let dependency12 = builtProductsRegistry[requirements[11]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[11]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11, dependency12))

        case 13:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            guard let dependency12 = builtProductsRegistry[requirements[11]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[11]) }
            guard let dependency13 = builtProductsRegistry[requirements[12]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[12]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11, dependency12, dependency13))

        case 14:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            guard let dependency12 = builtProductsRegistry[requirements[11]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[11]) }
            guard let dependency13 = builtProductsRegistry[requirements[12]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[12]) }
            guard let dependency14 = builtProductsRegistry[requirements[13]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[13]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11, dependency12, dependency13, dependency14))

        case 15:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            guard let dependency12 = builtProductsRegistry[requirements[11]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[11]) }
            guard let dependency13 = builtProductsRegistry[requirements[12]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[12]) }
            guard let dependency14 = builtProductsRegistry[requirements[13]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[13]) }
            guard let dependency15 = builtProductsRegistry[requirements[14]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[14]) }
            result = try factory((dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11, dependency12, dependency13, dependency14, dependency15))

        default:
            throw E.factoryBuilderHasTooManyArguments(name: vertex, count: requirements.count)
        }

        return result
    }

    private mutating func executeLateInitialization() throws {
        guard let sortedVertices = lateInitDependencyGraph.topologicalSort()
        else { throw E.lateInitCyclesDetected(cycles: lateInitDependencyGraph.detectCycles()) }

        for vertex in sortedVertices {
            self.builtProductsRegistry[vertex] = try self.lateInitialize(vertex)
        }
    }

    private func lateInitialize(_ vertex: String) throws -> Any {
        guard var product = builtProductsRegistry[vertex]
        else { throw E.builtProductNotFoundForVertex(name: vertex) }

        guard let requirements = lateRequirementsByResultName[vertex]
        else { throw E.cannotRetrieveLateRequirementsForProduct(name: vertex) }

        guard let setup = factoryRegistry[vertex]?.lateInit
        else { throw E.cannotRetrieveFactoryLateInitialization(name: vertex) }

        // TODO: Apply variadic generics once available

        switch requirements.count {
        case 0:
            try setup(&product, ())

        case 1:
            guard let dependency = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            try setup(&product, dependency)

        case 2:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            try setup(&product, (dependency1, dependency2))

        case 3:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            try setup(&product, (dependency1, dependency2, dependency3))

        case 4:
            guard let dependency1 = builtProductsRegistry[requirements[0]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[0]) }
            guard let dependency2 = builtProductsRegistry[requirements[1]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[1]) }
            guard let dependency3 = builtProductsRegistry[requirements[2]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[2]) }
            guard let dependency4 = builtProductsRegistry[requirements[3]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[3]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4))

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
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5))

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
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6))

        case 7:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7))

        case 8:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8))

        case 9:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9))

        case 10:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10))

        case 11:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11))

        case 12:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            guard let dependency12 = builtProductsRegistry[requirements[11]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[11]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11, dependency12))

        case 13:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            guard let dependency12 = builtProductsRegistry[requirements[11]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[11]) }
            guard let dependency13 = builtProductsRegistry[requirements[12]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[12]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11, dependency12, dependency13))

        case 14:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            guard let dependency12 = builtProductsRegistry[requirements[11]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[11]) }
            guard let dependency13 = builtProductsRegistry[requirements[12]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[12]) }
            guard let dependency14 = builtProductsRegistry[requirements[13]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[13]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11, dependency12, dependency13, dependency14))

        case 15:
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
            guard let dependency7 = builtProductsRegistry[requirements[6]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[6]) }
            guard let dependency8 = builtProductsRegistry[requirements[7]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[7]) }
            guard let dependency9 = builtProductsRegistry[requirements[8]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[8]) }
            guard let dependency10 = builtProductsRegistry[requirements[9]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[9]) }
            guard let dependency11 = builtProductsRegistry[requirements[10]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[10]) }
            guard let dependency12 = builtProductsRegistry[requirements[11]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[11]) }
            guard let dependency13 = builtProductsRegistry[requirements[12]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[12]) }
            guard let dependency14 = builtProductsRegistry[requirements[13]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[13]) }
            guard let dependency15 = builtProductsRegistry[requirements[14]]
            else { throw E.builtProductNotFoundForVertex(name: requirements[14]) }
            try setup(&product, (dependency1, dependency2, dependency3, dependency4, dependency5, dependency6, dependency7, dependency8, dependency9, dependency10, dependency11, dependency12, dependency13, dependency14, dependency15))

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
                else { throw E.requirementNotFound(name: String(requirement), requestedBy: productName) }

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
                else { throw E.requirementNotFoundForLateInitialization(name: String(requirement), requestedBy: productName) }

                lateInitDependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }
    }
}

/// "(A, B)" -> ["A", "B"]
func splitTupleContent(_ tupleContent: String) -> [String] {
    guard tupleContent != "()" else { return [] }

    var tupleContent = tupleContent

    if tupleContent.hasPrefix("(") { tupleContent.removeFirst() }
    if tupleContent.hasSuffix(")") { tupleContent.removeLast() }

    var angleBracketCount = 0
    var curlyBracketCount = 0
    var squareBracketCount = 0
    var roundBracketCount = 0

    var splitted: [String] = []
    var lastAddedIndex = tupleContent.startIndex

    for i in tupleContent.indices {
        switch (tupleContent[i]) {
        case "(": roundBracketCount += 1
        case ")": roundBracketCount -= 1
        case "[": squareBracketCount += 1
        case "]": squareBracketCount -= 1
        case "{": curlyBracketCount += 1
        case "}": curlyBracketCount -= 1
        case "<": angleBracketCount += 1
        case ">": angleBracketCount -= 1
        case ",":
            if (roundBracketCount + squareBracketCount + curlyBracketCount + angleBracketCount == 0) {
                splitted.append(String(tupleContent[lastAddedIndex..<i])
                    .trimmingCharacters(in: .whitespaces))
                lastAddedIndex = tupleContent.index(after: i)
            }
        default: break
        }
    }

    splitted.append(String(tupleContent[lastAddedIndex..<tupleContent.endIndex])
        .trimmingCharacters(in: .whitespaces))

    return splitted
}

