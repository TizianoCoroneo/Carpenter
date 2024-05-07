
public protocol FactoryConvertible {
    func eraseToAnyFactory() -> [AnyFactory]
}

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

private func collectIdentifiers<each Element>(
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
