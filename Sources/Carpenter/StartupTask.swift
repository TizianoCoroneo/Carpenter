
public struct StartupTask<Requirement, LateRequirement>: FactoryConvertible {
    let key: DependencyKey<Void>
    let builder: (Requirement) throws -> Void
    let lateInit: (LateRequirement) throws -> Void
    let requirementName = String(describing: Requirement.self)
    let lateRequirementName = String(describing: LateRequirement.self)

    public init(
        _ name: String,
        _ builder: @escaping (Requirement) throws -> Void,
        lateInit: @escaping (LateRequirement) throws -> Void
    ) {
        self.key = DependencyKey(name: name)
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

    public func eraseToAnyFactory() -> [AnyFactory] {
        [ AnyFactory(
            key: key,
            requirementName: requirementName,
            lateRequirementName: lateRequirementName,
            kind: .startupTask,
            builder: {
                guard let requirement = $0 as? Requirement
                else {
                    throw CarpenterError.requirementHasMismatchingType(
                        resultName: key.name,
                        expected: requirementName,
                        type: String(describing: type(of: $0)))
                }

                return try self.builder(requirement)
            },
            lateInit: {
                guard let requirement = $1 as? LateRequirement
                else {
                    throw CarpenterError.lateRequirementHasMismatchingType(
                        resultName: key.name,
                        expected: requirementName,
                        type: String(describing: type(of: $0)))
                }

                try self.lateInit(requirement);
            }) ]
    }
}
