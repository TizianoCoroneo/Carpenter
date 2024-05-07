//
//public protocol DependencyContainer {
//    static var shared: Self { get }
//
//    init()
//}
//
//public extension DependencyContainer {
//    static var allFactories: [AnyFactory] {
//        Mirror(reflecting: shared).children
//            .compactMap { $0.value as? FactoryConvertible }
//            .flatMap { $0.eraseToAnyFactory() }
//    }
//}
