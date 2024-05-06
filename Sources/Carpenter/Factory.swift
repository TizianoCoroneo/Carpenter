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

@available(macOS 14.0.0, *)
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
                    guard let requirement = $0 as? (repeat each Requirement)
                    else {
                        throw CarpenterError.requirementHasMismatchingType(
                            resultName: productName.eraseToAnyDependencyKey(),
                            expected: requirementName,
                            type: .init(metatype: type(of: $0)))
                    }

                    return try self.builder(repeat each requirement)
                })
        ]
    }
}

@available(macOS 14.0.0, *)
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

                    guard let requirement = $1 as? (repeat each LateRequirement)
                    else {
                        throw CarpenterError.lateRequirementHasMismatchingType(
                            resultName: productName.eraseToAnyDependencyKey(),
                            expected: requirementName,
                            type: .init(metatype: type(of: $0)))
                    }

                    try self.lateInit(&product, repeat each requirement)
                    $0 = product
            })
        ]
    }
}

func collectIdentifiers<each Element>(
    for types: repeat (each Element).Type
) -> [AnyDependencyKey] {
    var list = [AnyDependencyKey]()

    func adder<T>(_ type: T.Type = T.self) {
        list.append(AnyDependencyKey.init(T.self))
    }

    repeat adder(each types)

    return list
}

//public struct Factory<Requirement, LateRequirement, Product>: FactoryConvertible {
//    var key: DependencyKey<Product>
//    var builder: (Requirement) throws -> Product
//    var lateInit: (inout Product, LateRequirement) throws -> Void
//    let requirementName = String(describing: Requirement.self)
//    let lateRequirementName = String(describing: LateRequirement.self)
//    let productName = String(describing: Product.self)
//
//    public init(
//        _ builder: @escaping (Requirement) throws -> Product,
//        lateInit: @escaping (inout Product, LateRequirement) throws -> Void
//    ) {
//        self.key = DependencyKey<Product>()
//        self.builder = builder
//        self.lateInit = lateInit
//    }
//
//    public init(
//        _ builder: @escaping (Requirement) throws -> Product,
//        lateInit: @escaping (inout Product) throws -> Void
//    ) where LateRequirement == Void {
//        self.init(
//            builder,
//            lateInit: { (x, _: Void) in try lateInit(&x) })
//    }
//
//    public init(
//        _ builder: @escaping (Requirement) throws -> Product
//    ) where LateRequirement == Void {
//        self.init(
//            builder,
//            lateInit: { (_, _: Void) in })
//    }
//
//    public func eraseToAnyFactory() -> [AnyFactory] {
//        [
//            AnyFactory(
//            key: DependencyKey<Product>(),
//            requirementName: requirementName,
//            lateRequirementName: lateRequirementName,
//            kind: .objectFactory,
//            builder: {
//                guard let requirement = $0 as? Requirement
//                else {
//                    throw CarpenterError.requirementHasMismatchingType(
//                        resultName: productName,
//                        expected: requirementName,
//                        type: String(describing: type(of: $0)))
//                }
//
//                return try self.builder(requirement)
//            },
//            lateInit: {
//                guard var product = $0 as? Product
//                else {
//                    throw CarpenterError.productHasMismatchingType(
//                        name: productName,
//                        type: String(describing: type(of: $0)))
//                }
//
//                guard let requirement = $1 as? LateRequirement
//                else {
//                    throw CarpenterError.lateRequirementHasMismatchingType(
//                        resultName: productName,
//                        expected: requirementName,
//                        type: String(describing: type(of: $0)))
//                }
//
//                try self.lateInit(&product, requirement)
//                $0 = product
//            })
//            ]
//    }
//}

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
        case early((Any) throws -> Any)
        case late((inout Any, Any) throws -> Void)
    }

    public init<Product>(
        key: DependencyKey<Product>,
        requirementName: [AnyDependencyKey],
        kind: Kind,
        builder: Builder
    ) {
        self.requirementName = requirementName
        self.productName = key.eraseToAnyDependencyKey()
        self.kind = kind
        self.builder = builder
    }

    let requirementName: [AnyDependencyKey]
    let productName: Vertex
    let kind: Kind
    let builder: Builder
}
