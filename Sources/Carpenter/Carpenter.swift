import SwiftGraph

/// A ``Factory`` describes how to create a value of type `Product` using a value of type `Requirement`, and how to set additional
/// properties on the `Product` value after intialization, using a value of type `LateRequirement`.
///
/// The initializer ``init(_ builder:)`` describes how to create a value of type `Product` from a value of `Requirement`.
///
///```swift
///let urlSessionFactory = Factory { URLSession.shared }
///// has type Factory<Void, Void, URLSession>
///
///let counterFactory = Factory { (x: Int) in Counter(count: x) }
///// has type Factory<Int, Void, Counter>
///
///let userFactory = Factory { (id: UUID, name: String) in
///    User(id: id, name: name)
///} lateInit: { (user: inout User, email: EmailAddress) in
///    user.email = email
///}
///// has type Factory<(UUID, String), EmailAddress, Counter>
///```

@available(iOS 17, macOS 14, *)
public struct Factory<each Requirement, Product>: FactoryConvertible {

    var builder: (repeat each Requirement) throws -> Product
    let requirementName: ContiguousArray<AnyDependencyKey>
    let productName: AnyDependencyKey

    public init(
        _ builder: @escaping (repeat each Requirement) throws -> Product
    ) {
        self.builder = builder
        self.requirementName = collectIdentifiers(for: repeat (each Requirement).self)
        self.productName = AnyDependencyKey(metatype: Product.self)
    }

    public func eraseToAnyFactory() -> [AnyFactory] {
        [
            AnyFactory(
                key: productName,
                requirementName: requirementName,
                kind: .objectFactory,
                builder: .early {
                    var count = 0

                    let requirement = try (
                        repeat cast(
                            $0,
                            to: (each Requirement).self,
                            index: &count,
                            requirementName: requirementName
                        )
                    )

                    return try self.builder(repeat each requirement)
                })
        ]
    }
}

@available(iOS 17, macOS 14, *)
public struct LateInit<each LateRequirement, Product>: FactoryConvertible {
    var lateInit: (inout Product, repeat each LateRequirement) throws -> Void
    let requirementName: ContiguousArray<AnyDependencyKey>
    let productName: AnyDependencyKey

    public init(
        lateInit: @escaping (inout Product, repeat each LateRequirement) throws -> Void
    ) {
        self.lateInit = lateInit
        self.requirementName = collectIdentifiers(for: repeat (each LateRequirement).self)
        self.productName = AnyDependencyKey(metatype: Product.self)
    }

    public func eraseToAnyFactory() -> [AnyFactory] {
        [
            AnyFactory(
                key: productName,
                requirementName: requirementName,
                kind: .objectFactory,
                builder: .late {
                    guard var product = $0 as? Product
                    else {
                        throw CarpenterError.productHasMismatchingType(
                            name: productName,
                            type: .init(metatype: type(of: $0)))
                    }

                    var count = 0
                    func cast<R>(_ value: [Any], to r: R.Type = R.self) throws -> R {
                        defer { count += 1 }
                        guard let castValue = value[count] as? R else {
                            throw CarpenterError.lateRequirementHasMismatchingType(
                                resultName: productName,
                                expected: requirementName,
                                type: .init(metatype: type(of: value[count])))
                        }
                        return castValue
                    }

                    let requirement = try (repeat cast($1, to: (each LateRequirement).self))
                    try self.lateInit(&product, repeat each requirement)
                    $0 = product
            })
        ]
    }
}

func collectIdentifiers<each Element>(
    for types: repeat (each Element).Type
) -> ContiguousArray<AnyDependencyKey> {
    var list = ContiguousArray<AnyDependencyKey>()

    func adder<T>(_ type: T.Type = T.self) {
        list.append(AnyDependencyKey(
            key: .objectIdentifier(ObjectIdentifier(T.self)),
            displayName: { String(describing: T.self) }))
    }

    repeat adder(each types)

    return list
}

private func cast<R>(
    _ value: [Any],
    to r: R.Type = R.self,
    index: inout Int,
    requirementName: ContiguousArray<Vertex>
) throws -> R {
    defer { index += 1 }
    guard let castValue = value[index] as? R else {
        throw CarpenterError.requirementHasMismatchingType(
            resultName: .init(metatype: R.self),
            expected: requirementName,
            type: .init(metatype: type(of: value[index])))
    }
    return castValue
}

public protocol FactoryConvertible {
    func eraseToAnyFactory() -> [AnyFactory]
}

public struct AnyFactory {
    public enum Kind: Codable {
        case objectFactory
        case startupTask
        case protocolFactory
    }

    public enum Builder {
        case early(([Any]) throws -> Any)
        case late((inout Any, [Any]) throws -> Void)
    }

    public init(
        key: AnyDependencyKey,
        requirementName: ContiguousArray<AnyDependencyKey>,
        kind: Kind,
        builder: Builder
    ) {
        self.requirementName = requirementName
        self.productName = key
        self.kind = kind
        self.builder = builder
    }

    let requirementName: ContiguousArray<AnyDependencyKey>
    let productName: AnyDependencyKey
    let kind: Kind
    let builder: Builder
}


@propertyWrapper public struct GetDependency<P> {
    public var wrappedValue: P {
        try! tryGet()
    }

    public func tryGet() throws -> P {
        try carpenter().get(key)
    }

    let carpenter: () -> Carpenter
    let key: DependencyKey<P>

    @available(iOS 17, macOS 14, *)
    public init<Container: DependencyContainer, each Requirement>(
        carpenter: @autoclosure @escaping () -> Carpenter = .shared,
        _ keyPath: KeyPath<Container, Factory<repeat each Requirement, P>>
    ) {
        self.carpenter = carpenter
        self.key = DependencyKey<P>()
    }

    @available(iOS 17, macOS 14, *)
    public init<Container: DependencyContainer, C>(
        carpenter: @autoclosure @escaping () -> Carpenter = .shared,
        _ keyPath: KeyPath<Container, ProtocolWrapper<C, P>>
    ) {
        self.carpenter = carpenter
        self.key = DependencyKey<P>()
    }

    public init<Container: DependencyContainer>(
        carpenter: @autoclosure @escaping () -> Carpenter = .shared,
        _ keyPath: KeyPath<Container, DependencyKey<P>>
    ) {
        self.carpenter = carpenter
        self.key = Container.shared[keyPath: keyPath]
    }
}


@available(iOS 17, macOS 14, *)
public struct ProtocolWrapper<ConcreteType, ProtocolType>: FactoryConvertible {
    let concreteKey: AnyDependencyKey
    let protocolKey: AnyDependencyKey

    let cast: (ConcreteType) -> ProtocolType

    public init(
        cast: @escaping (ConcreteType) -> ProtocolType
    ) {
        self.concreteKey = AnyDependencyKey(metatype: ConcreteType.self)
        self.protocolKey = AnyDependencyKey(metatype: ProtocolType.self)
        self.cast = cast
    }

    public func eraseToAnyFactory() -> [AnyFactory] {
        [AnyFactory(
            key: protocolKey,
            requirementName: [concreteKey],
            kind: .protocolFactory,
            builder: .early {
                guard let concrete = $0[0] as? ConcreteType
                else {
                    throw CarpenterError.requirementHasMismatchingType(
                        resultName: protocolKey,
                        expected: [concreteKey],
                        type: .init(metatype: type(of: $0)))
                }

                return self.cast(concrete)
            })
         ]
    }
}

@available(iOS 17, macOS 14, *)
public struct StartupTask<each Requirement, LateRequirement>: FactoryConvertible {
    let key: AnyDependencyKey
    let builder: (repeat each Requirement) throws -> Void
    let requirementName: ContiguousArray<AnyDependencyKey>

    public init(
        _ name: String,
        _ builder: @escaping (repeat each Requirement) throws -> Void
    ) {
        self.key = .init(name: name)
        self.builder = builder
        self.requirementName = collectIdentifiers(for: repeat (each Requirement).self)
    }

    public func eraseToAnyFactory() -> [AnyFactory] {
        [ AnyFactory(
            key: key,
            requirementName: requirementName,
            kind: .startupTask,
            builder: .early {
                var count = 0

                let requirement = try (
                    repeat cast(
                        $0,
                        to: (each Requirement).self,
                        index: &count,
                        requirementName: requirementName
                    )
                )

                return try self.builder(repeat each requirement)
            })
        ]
    }
}


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

    init(name: String) {
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

@resultBuilder
public struct FactoryBuilder {

    public static func buildExpression(
        _ value: some FactoryConvertible
    ) -> [AnyFactory] {
        value.eraseToAnyFactory()
    }

    public static func buildExpression(
        _ value: AnyFactory
    ) -> [AnyFactory] {
        [value]
    }

    public static func buildExpression(
        _ value: [AnyFactory]
    ) -> [AnyFactory] {
        value
    }

    public static func buildBlock(_ components: [AnyFactory]...) -> [AnyFactory] {
        components.flatMap { $0 }
    }

    public static func buildArray(_ components: [[AnyFactory]]) -> [AnyFactory] {
        components.flatMap { $0 }
    }

    public static func buildEither(first component: [AnyFactory]) -> [AnyFactory] {
        component
    }

    public static func buildEither(second component: [AnyFactory]) -> [AnyFactory] {
        component
    }

    public static func buildLimitedAvailability(_ component: [AnyFactory]) -> [AnyFactory] {
        component
    }
}

public protocol DependencyContainer {
    static var shared: Self { get }

    init()
}

public extension DependencyContainer {
    static var allFactories: [AnyFactory] {
        Mirror(reflecting: shared).children
            .compactMap { $0.value as? FactoryConvertible }
            .flatMap { $0.eraseToAnyFactory() }
    }
}


public enum CarpenterError: Error, Equatable, CustomStringConvertible {
    case requirementNotFound(name: Vertex, requestedBy: Vertex)
    case requirementNotFoundForLateInitialization(name: Vertex, requestedBy: Vertex)
    case requirementHasMismatchingType(resultName: Vertex, expected: ContiguousArray<Vertex>, type: Vertex)
    case lateRequirementHasMismatchingType(resultName: Vertex, expected: ContiguousArray<Vertex>, type: Vertex)
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
