//
//  CarpenterEnvironmentKey.swift
//  
//
//  Created by Tiziano Coroneo on 08/10/2022.
//

@_exported import Carpenter
import SwiftUI

public protocol CarpenterEnvironmentKey: EnvironmentKey {
    associatedtype Requirement
    associatedtype LateRequirement
    associatedtype Product

    static var defaultFactory: Factory<Requirement, LateRequirement, Product> { get }
}

public extension CarpenterEnvironmentKey {
    static var defaultValue: Product { try! Carpenter.shared.get(defaultFactory) }
}
