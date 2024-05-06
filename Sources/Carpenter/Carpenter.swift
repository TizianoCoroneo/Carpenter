import SwiftGraph

public enum DependencyKey<Product>: CustomStringConvertible, Hashable {
    case objectIdentifier(ObjectIdentifier)
    case name(String)

    private init(_ name: ObjectIdentifier) {
        self = .objectIdentifier(name)
    }

    public init(_ name: String) {
        self = .name(name)
    }

    public init(_ type: Product.Type = Product.self) {
        self.init(ObjectIdentifier(type))
    }

    public var description: String {
        switch self {
        case .objectIdentifier:
            return String(describing: Product.self)
        case .name(let string):
            return string
        }
    }

    func eraseToAnyDependencyKey() -> AnyDependencyKey {
        switch self {
        case .objectIdentifier(let objectIdentifier):
            .init(
                key: .objectIdentifier(objectIdentifier),
                displayName: { String(describing: Product.self) })
        case .name(let string):
            .init(
                key: .name(string),
                displayName: { String(describing: Product.self) })
        }
    }
}

public struct AnyDependencyKey: Hashable, CustomStringConvertible {
    enum Key: Hashable {
        case objectIdentifier(ObjectIdentifier)
        case name(String)
    }

    let key: Key
    let displayName: () -> String

    init(key: Key, displayName: @escaping () -> String) {
        self.key = key
        self.displayName = displayName
    }

    init(_ objectIdentifier: ObjectIdentifier) {
        self.init(
            key: Key.objectIdentifier(objectIdentifier),
            displayName: { String(describing: objectIdentifier) })
    }

    init(_ name: String) {
        self.init(key: .name(name), displayName: { name })
    }

    init<T>(_ type: T.Type = T.self) {
        self.init(
            key: Key.objectIdentifier(ObjectIdentifier(T.self)),
            displayName: { String(describing: T.self) })
    }

    init(metatype: Any.Type) {
        self.init(
            key: Key.objectIdentifier(ObjectIdentifier(metatype)),
            displayName: { String(describing: metatype) })
    }

    public static func ==(_ l: AnyDependencyKey, _ r: AnyDependencyKey) -> Bool { l.key == r.key }
    public func hash(into hasher: inout Hasher) { hasher.combine(key) }
    public var description: String { displayName() }
}

public typealias Vertex = AnyDependencyKey

public struct Carpenter {

    public static var shared: Carpenter = .init()

    private typealias E = CarpenterError

    public private(set) var dependencyGraph: UnweightedGraph<AnyDependencyKey> = .init()
    public private(set) var lateInitDependencyGraph: UnweightedGraph<AnyDependencyKey> = .init()
    private(set) var factoryRegistry: [AnyDependencyKey: AnyFactory] = [:]
    private(set) var lateFactoryRegistry: [AnyDependencyKey: AnyFactory] = [:]
    private var builtProductsRegistry: [AnyDependencyKey: Any] = [:]
    private var requirementsByResultName: [AnyDependencyKey: [AnyDependencyKey]] = [:]
    private var lateRequirementsByResultName: [AnyDependencyKey: [AnyDependencyKey]] = [:]
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

    @available(macOS 14.0.0, *)
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

    private func lateInitialize(_ vertex: Vertex) throws -> Any {
        guard var product = builtProductsRegistry[vertex]
        else { throw E.builtProductNotFoundForVertex(name: vertex) }

        guard let requirements = lateRequirementsByResultName[vertex]
        else { throw E.cannotRetrieveLateRequirementsForProduct(name: vertex) }

        guard case .late(let setup) = lateFactoryRegistry[vertex]?.builder
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
            else { throw E.productNotFound(name: productName) }

            for requirement in requirementsNames {
                guard let requirementIndex = dependencyGraph.indexOfVertex(requirement)
                else { throw E.requirementNotFound(name: requirement, requestedBy: productName) }

                dependencyGraph.addEdge(
                    UnweightedEdge(u: requirementIndex, v: productIndex, directed: true),
                    directed: true)
            }
        }

        for (productName, requirementsNames) in lateRequirementsByResultName {
            guard let productIndex = lateInitDependencyGraph.indexOfVertex(productName)
            else { throw E.productNotFoundForLateInitialization(name: productName) }

            for requirement in requirementsNames {
                guard let requirementIndex = lateInitDependencyGraph.indexOfVertex(requirement)
                else { throw E.requirementNotFoundForLateInitialization(name: requirement, requestedBy: productName) }

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

    var tupleContent = Substring(tupleContent).utf8

    if tupleContent[tupleContent.startIndex] == 0x28 { tupleContent.removeFirst() }
    if tupleContent[tupleContent.index(before: tupleContent.endIndex)] == 0x29 { tupleContent.removeLast() }

    var angleBracketCount = 0
    var curlyBracketCount = 0
    var squareBracketCount = 0
    var roundBracketCount = 0

    var lastAddedIndex = tupleContent.startIndex

    let elementsWithIndex = zip(tupleContent, tupleContent.indices)

    var splitted: [Substring.UTF8View] = []

    for (element, index) in elementsWithIndex {
        switch (element) {
        case 0x28 /* ( */: roundBracketCount += 1
        case 0x29 /* ) */: roundBracketCount -= 1
        case 0x5b /* [ */: squareBracketCount += 1
        case 0x5d /* ] */: squareBracketCount -= 1
        case 0x7b /* { */: curlyBracketCount += 1
        case 0x7d /* } */: curlyBracketCount -= 1
        case 0x3c /* < */: angleBracketCount += 1
        case 0x3e /* > */: angleBracketCount -= 1
        case 0x2c /* , */:
            if (roundBracketCount + squareBracketCount + curlyBracketCount + angleBracketCount == 0) {
                splitted.append(tupleContent[lastAddedIndex..<index])
                lastAddedIndex = tupleContent.index(index, offsetBy: 2) // Count the space after the comma as well
            }
        default: break
        }
    }
    splitted.append(tupleContent[lastAddedIndex..<tupleContent.endIndex])
    return splitted.map { x in String(Substring(x)) }
}
