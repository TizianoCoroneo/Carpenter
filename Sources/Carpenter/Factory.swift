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
    var builder: (Requirement) async throws -> Product
    var lateInit: (inout Product, LateRequirement) async throws -> Void

    public init(
        _ builder: @escaping (Requirement) async throws -> Product,
        lateInit: @escaping (inout Product, LateRequirement) async throws -> Void
    ) {
        self.builder = builder
        self.lateInit = lateInit
    }

    public init(
        _ builder: @escaping (Requirement) async throws -> Product,
        lateInit: @escaping (inout Product) async throws -> Void
    ) where LateRequirement == Void {
        self.init(
            builder,
            lateInit: { (x, _: Void) in try await lateInit(&x) })
    }

    public init(
        _ builder: @escaping (Requirement) async throws -> Product
    ) where LateRequirement == Void {
        self.init(
            builder,
            lateInit: { (_, _: Void) in })
    }

    public func eraseToAnyFactory() -> AnyFactory {
        AnyFactory(
            requirementName: String(describing: Requirement.self),
            lateRequirementName: String(describing: LateRequirement.self),
            resultName: String(describing: Product.self),
            builder: {
                guard let requirement = $0 as? Requirement
                else {
                    throw CarpenterError.requirementHasMismatchingType(
                        resultName: String(describing: Product.self),
                        expected: String(describing: Requirement.self),
                        type: String(describing: type(of: $0)))
                }

                return try await self.builder(requirement)
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

                try await self.lateInit(&product, requirement)
                $0 = product
            })
    }
}

public protocol FactoryConvertible {
    func eraseToAnyFactory() -> AnyFactory
}

public struct AnyFactory {
    public init(
        requirementName: String,
        lateRequirementName: String,
        resultName: String,
        builder: @escaping (Any) async throws -> Any,
        lateInit: @escaping (inout Any, Any) async throws -> Void
    ) {
        self.requirementName = requirementName
        self.lateRequirementName = lateRequirementName
        self.resultName = resultName
        self.builder = builder
        self.lateInit = lateInit
    }

    let requirementName: String
    let lateRequirementName: String
    let resultName: String

    let builder: (Any) async throws -> Any
    let lateInit: (inout Any, Any) async throws -> Void
}
