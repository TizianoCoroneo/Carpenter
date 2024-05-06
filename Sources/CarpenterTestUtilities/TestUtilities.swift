
import Carpenter
import class Foundation.Bundle

// MARK: - Factories

public enum Dependency {

    public static var i = Factory { 0 }

    public static var keychain = Factory(Keychain.init) { (x: inout Keychain) in
        x.i = 10
    }

    public static var authClient = Factory(AuthClient.init) { (x: inout AuthClient, k: Keychain) in
        x.i = k.i * 2
    }
    public static var urlSession = Factory { Session.shared }
    public static var apiClient = Factory(ApiClient.init)
    public static var threeDependenciesObject = Factory(ThreeDependenciesObject.init)
    public static var fourDependenciesObject = Factory(FourDependenciesObject.init)
    public static var fiveDependenciesObject = Factory(FiveDependenciesObject.init) { (x: inout FiveDependenciesObject, k: Keychain) in
        x.i = k.i * 4
    }
    public static var sixDependenciesObject = Factory(SixDependenciesObject.init) { (x: inout SixDependenciesObject) in
        x.i = 7
    }
    public static var sixteenDependenciesObject = Factory(SixteenDependenciesObject.init)
    public static var cycleA = Factory(CycleA.init)
    public static var cycleB = Factory(CycleB.init)
    public static var cycleC = Factory(CycleC.init)
    public static var a = Factory(A.init)
    public static var b = Factory(B.init)
    public static var c = Factory(C.init)
    public static var d = Factory(D.init)
    public static var e = Factory(E.init)
    public static var f = Factory(F.init)
    public static var g = Factory(G.init)
    public static var h = Factory(H.init)
    public static var i2 = Factory(I.init)
    public static var j = Factory(J.init)

    public static let array = Factory {
        [1, 2, 3]
    }

    public static let dictionary = Factory {
        ["a": 1, "b": 2, "c": 3]
    }

    public static let consumeArrayAndDictionary = Factory { (a: [Int], b: [String: Int]) in
        TestGeneric(a: a, b: b)
    }

    public struct TestGeneric<A, B> {
        let a: A
        let b: B
    }
}

// MARK: - Example data structures

public class Keychain {
    public var i: Int

    public init(i: Int) {
        self.i = i
    }
}

public struct Session {
    public static let shared = Session()
}

public class AuthClient {
    public let keychain: Keychain
    public var i: Int

    public init(keychain: Keychain, i: Int) {
        self.keychain = keychain
        self.i = i
    }
}

public struct ApiClient {
    public let urlSession: Session
    public let authentication: AuthClient
    public var i: Int

    public init(urlSession: Session, authentication: AuthClient, i: Int) {
        self.urlSession = urlSession
        self.authentication = authentication
        self.i = i
    }
}

public struct ThreeDependenciesObject {
    public let apiClient: ApiClient
    public let authClient: AuthClient
    public var i: Int

    public init(apiClient: ApiClient, authClient: AuthClient, i: Int) {
        self.apiClient = apiClient
        self.authClient = authClient
        self.i = i
    }
}

public struct FourDependenciesObject {
    public let apiClient: ApiClient
    public let authClient: AuthClient
    public let threeDependenciesObject: ThreeDependenciesObject
    public var i: Int

    public init(apiClient: ApiClient, authClient: AuthClient, threeDependenciesObject: ThreeDependenciesObject, i: Int) {
        self.apiClient = apiClient
        self.authClient = authClient
        self.threeDependenciesObject = threeDependenciesObject
        self.i = i
    }
}

public struct FiveDependenciesObject {
    public let apiClient: ApiClient
    public let authClient: AuthClient
    public let threeDependenciesObject: ThreeDependenciesObject
    public let fourDependenciesObject: FourDependenciesObject
    public var i: Int

    public init(apiClient: ApiClient, authClient: AuthClient, threeDependenciesObject: ThreeDependenciesObject, fourDependenciesObject: FourDependenciesObject, i: Int) {
        self.apiClient = apiClient
        self.authClient = authClient
        self.threeDependenciesObject = threeDependenciesObject
        self.fourDependenciesObject = fourDependenciesObject
        self.i = i
    }
}

public struct SixDependenciesObject {
    public let apiClient: ApiClient
    public let authClient: AuthClient
    public let threeDependenciesObject: ThreeDependenciesObject
    public let fourDependenciesObject: FourDependenciesObject
    public let fiveDependenciesObject: FiveDependenciesObject
    public var i: Int

    public init(apiClient: ApiClient, authClient: AuthClient, threeDependenciesObject: ThreeDependenciesObject, fourDependenciesObject: FourDependenciesObject, fiveDependenciesObject: FiveDependenciesObject, i: Int) {
        self.apiClient = apiClient
        self.authClient = authClient
        self.threeDependenciesObject = threeDependenciesObject
        self.fourDependenciesObject = fourDependenciesObject
        self.fiveDependenciesObject = fiveDependenciesObject
        self.i = i
    }
}

public struct A {
    let i: Int
}

public struct B {
    let i: Int
}

public struct C {
    let i: Int
}

public struct D {
    let i: Int
}

public struct E {
    let i: Int
}

public struct F {
    let i: Int
}

public struct G {
    let i: Int
}

public struct H {
    let i: Int
}

public struct I {
    let i: Int
}

public struct J {
    let i: Int
}

public struct SixteenDependenciesObject {
    public let apiClient: ApiClient
    public let authClient: AuthClient
    public let threeDependenciesObject: ThreeDependenciesObject
    public let fourDependenciesObject: FourDependenciesObject
    public let fiveDependenciesObject: FiveDependenciesObject
    public let sixDependenciesObject: FiveDependenciesObject
    public let a: A
    public let b: B
    public let c: C
    public let d: D
    public let e: E
    public let f: F
    public let g: G
    public let h: H
    public let i: I
    public var j: Int

    public init(apiClient: ApiClient, authClient: AuthClient, threeDependenciesObject: ThreeDependenciesObject, fourDependenciesObject: FourDependenciesObject, fiveDependenciesObject: FiveDependenciesObject, sixDependenciesObject: FiveDependenciesObject, a: A, b: B, c: C, d: D, e: E, f: F, g: G, h: H, i: I, j: Int) {
        self.apiClient = apiClient
        self.authClient = authClient
        self.threeDependenciesObject = threeDependenciesObject
        self.fourDependenciesObject = fourDependenciesObject
        self.fiveDependenciesObject = fiveDependenciesObject
        self.sixDependenciesObject = sixDependenciesObject
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.e = e
        self.f = f
        self.g = g
        self.h = h
        self.i = i
        self.j = j
    }
}


public class CycleA {
    public let b: CycleB

    public init(b: CycleB) {
        self.b = b
    }
}

public class CycleB {
    public let c: CycleC

    public init(c: CycleC) {
        self.c = c
    }
}

public class CycleC {
    public let a: CycleA

    public init(a: CycleA) {
        self.a = a
    }
}

public extension Bundle {
    static let visualizationBundleURL = Bundle.module.url(forResource: "VisualizationBundle", withExtension: "json")!
}
