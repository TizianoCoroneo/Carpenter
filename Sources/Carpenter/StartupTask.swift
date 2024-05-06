
@available(iOS 17, macOS 14, *)
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
                var count = 0
                func cast<R>(_ value: [Any], to r: R.Type = R.self) throws -> R {
                    defer { count += 1 }
                    guard let castValue = value[count] as? R else {
                        throw CarpenterError.requirementHasMismatchingType(
                            resultName: key.eraseToAnyDependencyKey(),
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
