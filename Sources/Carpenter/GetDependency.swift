

@propertyWrapper public struct GetDependency<P> {
    public var wrappedValue: P {
        try! tryGet()
    }

    public func tryGet() throws -> P {
        try carpenter().get(key)
    }

    let carpenter: () -> Carpenter
    let key: DependencyKey<P>

    @available(iOS 17, macOS 14, *)
    public init<Container: DependencyContainer, each Requirement>(
        carpenter: @autoclosure @escaping () -> Carpenter = .shared,
        _ keyPath: KeyPath<Container, Factory<repeat each Requirement, P>>
    ) {
        self.carpenter = carpenter
        self.key = DependencyKey<P>()
    }

//    public init<Container: DependencyContainer, C>(
//        carpenter: @autoclosure @escaping () -> Carpenter = .shared,
//        _ keyPath: KeyPath<Container, ProtocolWrapper<C, P>>
//    ) {
//        self.carpenter = carpenter
//        self.key = DependencyKey<P>()
//    }

    public init<Container: DependencyContainer>(
        carpenter: @autoclosure @escaping () -> Carpenter = .shared,
        _ keyPath: KeyPath<Container, DependencyKey<P>>
    ) {
        self.carpenter = carpenter
        self.key = Container.shared[keyPath: keyPath]
    }
}
