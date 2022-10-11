
public struct StartupTask<Requirement, LateRequirement>: FactoryConvertible {
    let name: String
    var builder: (Requirement) throws -> Void
    var lateInit: (LateRequirement) throws -> Void

    public init(
        _ name: String,
        _ builder: @escaping (Requirement) throws -> Void,
        lateInit: @escaping (LateRequirement) throws -> Void
    ) {
        self.name = name
        self.builder = builder
        self.lateInit = lateInit
    }

    public init(
        _ name: String,
        lateInit: @escaping (LateRequirement) throws -> Void
    ) where Requirement == Void {
        self.init(
            name,
            {},
            lateInit: lateInit)
    }

    public init(
        _ name: String,
        _ builder: @escaping (Requirement) throws -> Void
    ) where LateRequirement == Void {
        self.init(
            name,
            builder,
            lateInit: { (_: Void) in })
    }

    public func eraseToAnyFactory() -> AnyFactory {
        AnyFactory(
            requirementName: String(describing: Requirement.self),
            lateRequirementName: String(describing: LateRequirement.self),
            resultName: name,
            builder: {
                guard let requirement = $0 as? Requirement
                else {
                    throw CarpenterError.requirementHasMismatchingType(
                        resultName: self.name,
                        expected: String(describing: Requirement.self),
                        type: String(describing: type(of: $0)))
                }

                return try self.builder(requirement)
            },
            lateInit: {
                guard let requirement = $1 as? LateRequirement
                else {
                    throw CarpenterError.lateRequirementHasMismatchingType(
                        resultName: self.name,
                        expected: String(describing: Requirement.self),
                        type: String(describing: type(of: $0)))
                }

                try self.lateInit(requirement);
            })
    }
}
