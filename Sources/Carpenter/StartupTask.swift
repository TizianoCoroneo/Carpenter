
@available(macOS 14.0.0, *)
public struct StartupTask<each Requirement, LateRequirement>: FactoryConvertible {
    let key: DependencyKey<Void>
    let builder: (repeat each Requirement) throws -> Void
    let requirementName = collectIdentifiers(for: repeat (each Requirement).self)

    public init(
        _ name: String,
        _ builder: @escaping (repeat each Requirement) throws -> Void
    ) {
        self.key = DependencyKey.name(name)
        self.builder = builder
    }

    public func eraseToAnyFactory() -> [AnyFactory] {
        [ AnyFactory(
            key: key,
            requirementName: requirementName,
            kind: .startupTask,
            builder: .early {
                guard let requirement = $0 as? (repeat each Requirement)
                else {
                    throw CarpenterError.requirementHasMismatchingType(
                        resultName: key.eraseToAnyDependencyKey(),
                        expected: requirementName,
                        type: .init(metatype: type(of: $0)))
                }

                return try self.builder(repeat each requirement)
            })
        ]
    }
}
