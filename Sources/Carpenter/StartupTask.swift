//
//  StartupTask.swift
//  
//
//  Created by Tiziano Coroneo on 08/10/2022.
//

public struct StartupTask<Requirement, LateRequirement>: FactoryConvertible {
    let name: String
    var builder: (Requirement) async throws -> Void
    var lateInit: (LateRequirement) async throws -> Void

    public init(
        _ name: String,
        _ builder: @escaping (Requirement) async throws -> Void,
        lateInit: @escaping (LateRequirement) async throws -> Void
    ) {
        self.name = name
        self.builder = builder
        self.lateInit = lateInit
    }

    public init(
        _ name: String,
        lateInit: @escaping (LateRequirement) async throws -> Void
    ) where Requirement == Void {
        self.init(
            name,
            {},
            lateInit: lateInit)
    }

    public init(
        _ name: String,
        _ builder: @escaping (Requirement) async throws -> Void
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

                return try await self.builder(requirement)
            },
            lateInit: {
                guard let requirement = $1 as? LateRequirement
                else {
                    throw CarpenterError.lateRequirementHasMismatchingType(
                        resultName: self.name,
                        expected: String(describing: Requirement.self),
                        type: String(describing: type(of: $0)))
                }

                try await self.lateInit(requirement);
            })
    }
}
