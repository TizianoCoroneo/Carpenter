
@resultBuilder
public struct FactoryBuilder {

    public static func buildExpression(
        _ value: some FactoryConvertible
    ) -> AnyFactory {
        value.eraseToAnyFactory()
    }

    public static func buildBlock(_ components: AnyFactory...) -> [AnyFactory] {
        components
    }

    public static func buildArray(_ components: [[AnyFactory]]) -> [AnyFactory] {
        components.flatMap { $0 }
    }

    public static func buildEither(first component: [AnyFactory]) -> [AnyFactory] {
        component
    }

    public static func buildEither(second component: [AnyFactory]) -> [AnyFactory] {
        component
    }

    public static func buildLimitedAvailability(_ component: [AnyFactory]) -> [AnyFactory] {
        component
    }

    public static func buildFinalResult(_ components: [AnyFactory]) -> Result<Carpenter, Error> {
        Result {
            var c = Carpenter()
            for component in components {
                try c.add(component)
            }
            try c.finalizeGraph()
            return c
        }
    }
}
