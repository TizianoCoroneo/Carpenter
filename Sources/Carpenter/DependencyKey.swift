
public enum DependencyKey<Product>: CustomStringConvertible, Hashable {
    case objectIdentifier(ObjectIdentifier)
    case name(String)

    private init(_ name: ObjectIdentifier) {
        self = .objectIdentifier(name)
    }

    public init(_ name: String) {
        self = .name(name)
    }

    public init(_ type: Product.Type = Product.self) {
        self.init(ObjectIdentifier(type))
    }

    public var description: String {
        switch self {
        case .objectIdentifier:
            return String(describing: Product.self)
        case .name(let string):
            return string
        }
    }

    func eraseToAnyDependencyKey() -> AnyDependencyKey {
        switch self {
        case .objectIdentifier(let objectIdentifier):
            .init(
                key: .objectIdentifier(objectIdentifier),
                displayName: { String(describing: Product.self) })
        case .name(let string):
            .init(
                key: .name(string),
                displayName: { String(describing: Product.self) })
        }
    }
}

public struct AnyDependencyKey: Hashable, CustomStringConvertible {
    enum Key: Hashable {
        case objectIdentifier(ObjectIdentifier)
        case name(String)
    }

    let key: Key
    let displayName: () -> String

    init(key: Key, displayName: @escaping () -> String) {
        self.key = key
        self.displayName = displayName
    }

    init(_ objectIdentifier: ObjectIdentifier) {
        self.init(
            key: Key.objectIdentifier(objectIdentifier),
            displayName: { String(describing: objectIdentifier) })
    }

    init(name: String) {
        self.init(key: .name(name), displayName: { name })
    }

    init<T>(_ type: T.Type = T.self) {
        self.init(
            key: Key.objectIdentifier(ObjectIdentifier(T.self)),
            displayName: { String(describing: T.self) })
    }

    init(metatype: Any.Type) {
        self.init(
            key: Key.objectIdentifier(ObjectIdentifier(metatype)),
            displayName: { String(describing: metatype) })
    }

    public static func ==(_ l: AnyDependencyKey, _ r: AnyDependencyKey) -> Bool { l.key == r.key }
    public func hash(into hasher: inout Hasher) { hasher.combine(key) }
    public var description: String { displayName() }
}
