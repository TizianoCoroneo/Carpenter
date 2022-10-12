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
///
public struct Factory<Requirement, LateRequirement, Product>: FactoryConvertible {
    var key: DependencyKey<Product>
    var builder: (Requirement) throws -> Product
    var lateInit: (inout Product, LateRequirement) throws -> Void

    public init(
        _ builder: @escaping (Requirement) throws -> Product,
        lateInit: @escaping (inout Product, LateRequirement) throws -> Void
    ) {
        self.key = DependencyKey<Product>()
        self.builder = builder
        self.lateInit = lateInit
    }

    public init(
        _ builder: @escaping (Requirement) throws -> Product,
        lateInit: @escaping (inout Product) throws -> Void
    ) where LateRequirement == Void {
        self.init(
            builder,
            lateInit: { (x, _: Void) in try lateInit(&x) })
    }

    public init(
        _ builder: @escaping (Requirement) throws -> Product
    ) where LateRequirement == Void {
        self.init(
            builder,
            lateInit: { (_, _: Void) in })
    }

    public func eraseToAnyFactory() -> [AnyFactory] {
        AnyFactory(
            key: DependencyKey<Product>(),
            requirementName: String(describing: Requirement.self),
            lateRequirementName: String(describing: LateRequirement.self),
            resultName: String(describing: Product.self),
            kind: .objectFactory,
            builder: {
                guard let requirement = $0 as? Requirement
                else {
                    throw CarpenterError.requirementHasMismatchingType(
                        resultName: String(describing: Product.self),
                        expected: String(describing: Requirement.self),
                        type: String(describing: type(of: $0)))
                }

                return try self.builder(requirement)
            },
            lateInit: {
                guard var product = $0 as? Product
                else {
                    throw CarpenterError.productHasMismatchingType(
                        name: String(describing: Product.self),
                        type: String(describing: type(of: $0)))
                }

                guard let requirement = $1 as? LateRequirement
                else {
                    throw CarpenterError.lateRequirementHasMismatchingType(
                        resultName: String(describing: Product.self),
                        expected: String(describing: Requirement.self),
                        type: String(describing: type(of: $0)))
                }

                try self.lateInit(&product, requirement)
                $0 = product
            })
    }
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

    public init<Product>(
        key: DependencyKey<Product>,
        requirementName: String,
        lateRequirementName: String,
        resultName: String, // TODO: same as key.name, delete?
        kind: Kind,
        builder: @escaping (Any) throws -> Any,
        lateInit: @escaping (inout Any, Any) throws -> Void
    ) {
        self.requirementName = requirementName
        self.lateRequirementName = lateRequirementName
        self.resultName = resultName
        self.keyName = key.name
        self.kind = kind
        self.builder = builder
        self.lateInit = lateInit
    }

    let requirementName: String
    let lateRequirementName: String
    let resultName: String
    let keyName: String
    let kind: Kind

    let builder: (Any) throws -> Any
    let lateInit: (inout Any, Any) throws -> Void
}
