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
    
    var key = ObjectIdentifier(Product.self)
    var builder: (repeat each Requirement) throws -> Product
    let requirementName = collectIdentifiers(for: repeat (each Requirement).self)
    let productName = DependencyKey(Product.self)

    public init(
        _ builder: @escaping (repeat each Requirement) throws -> Product
    ) {
        self.builder = builder
    }

    public func eraseToAnyFactory() -> [AnyFactory] {
        [
            AnyFactory(
                key: DependencyKey<Product>(),
                requirementName: requirementName,
                kind: .objectFactory,
                builder: .early {
                    var count = 0
                    func cast<R>(_ value: [Any], to r: R.Type = R.self) throws -> R {
                        defer { count += 1 }
                        guard let castValue = value[count] as? R else {
                            throw CarpenterError.requirementHasMismatchingType(
                                resultName: productName.eraseToAnyDependencyKey(),
                                expected: requirementName,
                                type: .init(metatype: type(of: value[count])))
                        }
                        return castValue
                    }

                    let requirement = try (repeat cast($0, to: (each Requirement).self))
                    return try self.builder(repeat each requirement)
                })
        ]
    }
}

@available(iOS 17, macOS 14, *)
public struct LateInit<each LateRequirement, Product>: FactoryConvertible {
    var lateInit: (inout Product, repeat each LateRequirement) throws -> Void
    let requirementName = collectIdentifiers(for: repeat (each LateRequirement).self)
    let productName = DependencyKey(Product.self)

    public init(
        lateInit: @escaping (inout Product, repeat each LateRequirement) throws -> Void
    ) {
        self.lateInit = lateInit
    }

    public func eraseToAnyFactory() -> [AnyFactory] {
        [
            AnyFactory(
                key: DependencyKey<Product>(),
                requirementName: requirementName,
                kind: .objectFactory,
                builder: .late {
                    guard var product = $0 as? Product
                    else {
                        throw CarpenterError.productHasMismatchingType(
                            name: productName.eraseToAnyDependencyKey(),
                            type: .init(metatype: type(of: $0)))
                    }

                    var count = 0
                    func cast<R>(_ value: [Any], to r: R.Type = R.self) throws -> R {
                        defer { count += 1 }
                        guard let castValue = value[count] as? R else {
                            throw CarpenterError.lateRequirementHasMismatchingType(
                                resultName: productName.eraseToAnyDependencyKey(),
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

public protocol FactoryConvertible {
    @FactoryBuilder
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

    public init<Product>(
        key: DependencyKey<Product>,
        requirementName: ContiguousArray<AnyDependencyKey>,
        kind: Kind,
        builder: Builder
    ) {
        self.requirementName = requirementName
        self.productName = key.eraseToAnyDependencyKey()
        self.kind = kind
        self.builder = builder
    }

    let requirementName: ContiguousArray<AnyDependencyKey>
    let productName: Vertex
    let kind: Kind
    let builder: Builder
}
