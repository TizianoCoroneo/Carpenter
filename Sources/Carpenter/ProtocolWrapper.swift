//
//@available(iOS 17, macOS 14, *)
//public struct ProtocolWrapper<ConcreteType, ProtocolType>: FactoryConvertible {
//    let concreteKey: DependencyKey<ConcreteType>
//    let protocolKey: DependencyKey<ProtocolType>
//
//    let cast: (ConcreteType) -> ProtocolType
//
//    public init(
//        cast: @escaping (ConcreteType) -> ProtocolType
//    ) {
//        self.concreteKey = DependencyKey<ConcreteType>()
//        self.protocolKey = DependencyKey<ProtocolType>()
//        self.cast = cast
//    }
//
//    public func eraseToAnyFactory() -> [AnyFactory] {
//        [AnyFactory(
//            key: protocolKey,
//            requirementName: [concreteKey.eraseToAnyDependencyKey()],
//            kind: .protocolFactory,
//            builder: .early {
//                guard let concrete = $0[0] as? ConcreteType
//                else {
//                    throw CarpenterError.requirementHasMismatchingType(
//                        resultName: protocolKey.eraseToAnyDependencyKey(),
//                        expected: [concreteKey.eraseToAnyDependencyKey()],
//                        type: .init(metatype: type(of: $0)))
//                }
//
//                return self.cast(concrete)
//            })
//         ]
//    }
//}
