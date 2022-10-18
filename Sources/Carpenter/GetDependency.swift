
@propertyWrapper public struct GetDependency<P> {
    public var wrappedValue: P {
        try! tryGet()
    }

    public func tryGet() throws -> P {
        try carpenter().get(key)
    }

    let carpenter: () -> Carpenter
    let key: DependencyKey<P>

    public init<Container: DependencyContainer, R, L>(
        carpenter: @autoclosure @escaping () -> Carpenter = .shared,
        _ keyPath: KeyPath<Container, Factory<R, L, P>>
    ) {
        self.carpenter = carpenter
        self.key = DependencyKey<P>()
    }

    public init<Container: DependencyContainer, C>(
        carpenter: @autoclosure @escaping () -> Carpenter = .shared,
        _ keyPath: KeyPath<Container, ProtocolWrapper<C, P>>
    ) {
        self.carpenter = carpenter
        self.key = DependencyKey<P>()
    }

    public init<Container: DependencyContainer>(
        carpenter: @autoclosure @escaping () -> Carpenter = .shared,
        _ keyPath: KeyPath<Container, DependencyKey<P>>
    ) {
        self.carpenter = carpenter
        self.key = Container.shared[keyPath: keyPath]
    }
}
