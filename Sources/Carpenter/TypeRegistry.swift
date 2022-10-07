//
//  TypeRegistry.swift
//
//
//  Created by Tiziano Coroneo on 03/07/2021.
//

/// A `TypeRegistry` is a data structure that lets you associate a type `R` with a function with the signature `(P) -> R`.
///
/// The way this works is "register by type, retrieve by value": you can make 1 registration for each type, that correlates a type `T` to a closure `(T) -> Value`. When you use an instance of `T` to retrieve its `Value`, the `TypeRegistry` will find the right closure by checking the concrete type of `T`, and it will run it by passing it the same instance of `T`.
///
/// Use the `register` methods to set a specific function to be associated with a `T.Type`.
/// Then, you can use the `value(forType:)` function to run the corresponding function, which will return an instance of `Value`.
public struct TypeRegistry {

    private(set) var registry: [ObjectIdentifier: (Any) -> Any] = [:]

    public init() {}

    mutating func add<T, R>(_ registration: Registration<T, R>) {
        let registration = registration.eraseToAnyRegistration()
        registry[registration.objectId] = registration.valueForType
    }

    @discardableResult
    public mutating func register<T, R>(
        value: @escaping (T) -> R,
        forType typeReference: T.Type = T.self,
        resultType resultTypeReference: R.Type = R.self
    ) -> Self {
        add(Registration(valueForType: value))
        return self
    }

    @discardableResult
    public mutating func removeValue<T, R>(
        forResultType typeReference: R.Type = R.self
    ) -> ((T) -> R)? {
        registry.removeValue(forKey: ObjectIdentifier(typeReference)).map { $0 as! (T) -> R }
    }

    public func value<T, R>(
        forType typeInstance: T
    ) throws -> R {
        guard !registry.isEmpty
        else { throw RegistryError.emptyRegistry }

        guard let valueForType = registry[ObjectIdentifier(R.self)] as? (T) -> R
        else { throw RegistryError.typeNotFound(type(of: typeInstance)) }

        return valueForType(typeInstance)
    }
}

public enum RegistryError: Error {
    case emptyRegistry
    case typeNotFound(Any.Type)
}

struct Registration<T, R> {
    let valueForType: (T) -> R

    init(
        valueForType: @escaping (T) -> R
    ) {
        self.valueForType = valueForType
    }
}

struct AnyRegistration {
    let objectId: ObjectIdentifier
    let valueForType: (Any) -> Any
}

extension Registration {
    func eraseToAnyRegistration() -> AnyRegistration {
        AnyRegistration(
            objectId: ObjectIdentifier(R.self),
            valueForType: { anyTypeInstance in
                guard let typeInstance = anyTypeInstance as? T else {
                    preconditionFailure("Type of \(anyTypeInstance) does not match registered type: \(T.self)")
                }

                return valueForType(typeInstance)
            })
    }
}
