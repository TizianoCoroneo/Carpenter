
import Foundation

public struct ProtocolWrapper<R, L, ConcreteType, ProtocolType>: FactoryConvertible {
    let concreteKey: DependencyKey<ConcreteType>
    let protocolKey: DependencyKey<ProtocolType>

    let factory: Factory<R, L, ConcreteType>
    let cast: (ConcreteType) -> ProtocolType

    public init(
        _ factory: Factory<R, L, ConcreteType>,
        cast: @escaping (ConcreteType) -> ProtocolType
    ) {
        self.concreteKey = DependencyKey<ConcreteType>()
        self.protocolKey = DependencyKey<ProtocolType>()
        self.factory = factory
        self.cast = cast
    }

    public func eraseToAnyFactory() -> [AnyFactory] {
        AnyFactory(
            key: protocolKey,
            requirementName: concreteKey.name,
            lateRequirementName: String(describing: Void.self),
            resultName: String(describing: Void.self),
            kind: .protocolFactory,
            builder: {
                guard let concrete = $0 as? ConcreteType
                else {
                    throw CarpenterError.requirementHasMismatchingType(
                        resultName: protocolKey.name,
                        expected: concreteKey.name,
                        type: String(describing: type(of: $0)))
                }

                return self.cast(concrete)
            },
            lateInit: { _, _ in })

        factory
    }
}
