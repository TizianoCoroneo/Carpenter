
import Carpenter
import XCTest

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
    public static var sevenDependenciesObject = Factory(SevenDependenciesObject.init)
    public static var cycleA = Factory(CycleA.init)
    public static var cycleB = Factory(CycleB.init)
    public static var cycleC = Factory(CycleC.init)

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

    public static func startupTask1(exp: XCTestExpectation) -> StartupTask<ApiClient, Void> {
        StartupTask("Task 1") { (x: ApiClient) in
            exp.fulfill()
            print("Ran task 1")
        }
    }

    public static func startupTask2(exp: XCTestExpectation) -> StartupTask<Session, Void> {
        StartupTask("Task 2") { (x: Session) in
            exp.fulfill()
            print("Ran task 2")
        }
    }

    public static func startupTask3(exp: XCTestExpectation) -> StartupTask<AuthClient, Void> {
        StartupTask("Task 3") { (x: AuthClient) in
            exp.fulfill()
            print("Ran task 3")
        }
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

public struct SevenDependenciesObject {
    public let apiClient: ApiClient
    public let authClient: AuthClient
    public let threeDependenciesObject: ThreeDependenciesObject
    public let fourDependenciesObject: FourDependenciesObject
    public let fiveDependenciesObject: FiveDependenciesObject
    public let sixDependenciesObject: FiveDependenciesObject
    public var i: Int

    public init(apiClient: ApiClient, authClient: AuthClient, threeDependenciesObject: ThreeDependenciesObject, fourDependenciesObject: FourDependenciesObject, fiveDependenciesObject: FiveDependenciesObject, sixDependenciesObject: FiveDependenciesObject, i: Int) {
        self.apiClient = apiClient
        self.authClient = authClient
        self.threeDependenciesObject = threeDependenciesObject
        self.fourDependenciesObject = fourDependenciesObject
        self.fiveDependenciesObject = fiveDependenciesObject
        self.sixDependenciesObject = sixDependenciesObject
        self.i = i
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

// MARK: - Files

public extension Bundle {
    static let buildGraphURL = Bundle.module.url(forResource: "BuildGraph", withExtension: "json")!
    static let lateInitGraphURL = Bundle.module.url(forResource: "LateInitGraph", withExtension: "json")!
}

// MARK: - Assertions

public func XCTAssertThrowsAsync<T>(
    _ expression: @autoclosure @escaping () async throws -> T,
    errorHandler: (Error) async throws -> Void,
    file: StaticString = #file,
    line: UInt = #line
) async throws {
    do {
        _ = try await expression()
        XCTFail("Should have thrown an error", file: file, line: line)
    } catch {
        try await errorHandler(error)
    }
}

public func XCTAssertVertexExists(
    _ carpenter: Carpenter,
    name: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssert(carpenter.dependencyGraph.contains(name), "Cannot find vertex \"\(name)\"", file: file, line: line)
}

public func XCTAssertEdgeExists(
    _ carpenter: Carpenter,
    from: String,
    to: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(
        carpenter.dependencyGraph.edgeExists(
            from: from,
            to: to),
        "Cannot find edge from \"\(from)\" to \"\(to)\"",
        file: file,
        line: line)
}

