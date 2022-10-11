
@_exported import Carpenter
import SwiftUI

public protocol CarpenterEnvironmentKey: EnvironmentKey {
    associatedtype Product
    static var key: DependencyKey<Product> { get }
}

public extension CarpenterEnvironmentKey {
    static var defaultValue: Product { try! Carpenter.shared.get(key) }
}
