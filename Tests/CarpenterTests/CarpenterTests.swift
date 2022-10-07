import XCTest
@testable import Carpenter

enum Dependency {

    static var i = Factory { 0 }

    static var keychain = Factory(Keychain.init) { (x: inout Keychain) in
        x.i = 10
    }

    static var authClient = Factory(AuthClient.init) { (x: inout AuthClient, k: Keychain) in
        x.i = k.i * 2
    }
    static var urlSession = Factory { URLSession.shared }
    static var apiClient = Factory(ApiClient.init)
    static var threeDependenciesObject = Factory(ThreeDependenciesObject.init)
    static var fourDependenciesObject = Factory(FourDependenciesObject.init)
    static var fiveDependenciesObject = Factory(FiveDependenciesObject.init) { (x: inout FiveDependenciesObject, k: Keychain) in
        x.i = k.i * 4
    }
    static var sixDependenciesObject = Factory(SixDependenciesObject.init) { (x: inout SixDependenciesObject) in
        x.i = 7
    }
    static var sevenDependenciesObject = Factory(SevenDependenciesObject.init)
    static var cycleA = Factory(CycleA.init)
    static var cycleB = Factory(CycleB.init)
    static var cycleC = Factory(CycleC.init)
}

final class CarpenterTests: XCTestCase {

    func test_AddingDependeciesInOrder() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.threeDependenciesObject)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, name: "Int")
        XCTAssertVertexExists(carpenter, name: "ApiClient")
        XCTAssertVertexExists(carpenter, name: "NSURLSession")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")
        XCTAssertVertexExists(carpenter, name: "ThreeDependenciesObject")

        XCTAssertEdgeExists(carpenter, from: "Int", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "Keychain")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "NSURLSession", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "ApiClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ThreeDependenciesObject")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 6)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 9)

        print(carpenter.dependencyGraph.description)
    }

    func test_AddingDependeciesOutOfOrder() throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.i)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, name: "Int")
        XCTAssertVertexExists(carpenter, name: "ApiClient")
        XCTAssertVertexExists(carpenter, name: "NSURLSession")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")
        XCTAssertVertexExists(carpenter, name: "ThreeDependenciesObject")

        XCTAssertEdgeExists(carpenter, from: "Int", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "Keychain")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "NSURLSession", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "ApiClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ThreeDependenciesObject")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 6)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 9)

        print(carpenter.dependencyGraph.description)
    }

    func test_BuildProducts() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.keychain)

        try await carpenter.build()

        let _: Keychain = try carpenter.get(Dependency.keychain)
        let _: AuthClient = try carpenter.get(Dependency.authClient)
        let _: URLSession = try carpenter.get(Dependency.urlSession)
        let _: AuthClient = try carpenter.get(Dependency.authClient)
        let _: ThreeDependenciesObject = try carpenter.get(Dependency.threeDependenciesObject)
    }

    func test_FinalizeAndBuildProducts() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.keychain)

        try carpenter.finalizeGraph()
        try await carpenter.build()

        let _: Keychain = try carpenter.get(Dependency.keychain)
        let _: AuthClient = try carpenter.get(Dependency.authClient)
        let _: URLSession = try carpenter.get(Dependency.urlSession)
        let _: AuthClient = try carpenter.get(Dependency.authClient)
        let _: ThreeDependenciesObject = try carpenter.get(Dependency.threeDependenciesObject)
    }

    func test_BuildBigProducts() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.fourDependenciesObject)
        try carpenter.add(Dependency.fiveDependenciesObject)
        try carpenter.add(Dependency.sixDependenciesObject)

        try await carpenter.build()

        _ = try carpenter.get(Dependency.keychain)
        _ = try carpenter.get(Dependency.authClient)
        _ = try carpenter.get(Dependency.urlSession)
        _ = try carpenter.get(Dependency.apiClient)
        _ = try carpenter.get(Dependency.threeDependenciesObject)
        _ = try carpenter.get(Dependency.fourDependenciesObject)
        _ = try carpenter.get(Dependency.fiveDependenciesObject)
        _ = try carpenter.get(Dependency.sixDependenciesObject)
    }

    func test_BuildTooBigProducts() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.fourDependenciesObject)
        try carpenter.add(Dependency.fiveDependenciesObject)
        try carpenter.add(Dependency.sixDependenciesObject)
        try carpenter.add(Dependency.sevenDependenciesObject)

        try await XCTAssertThrowsAsync(try await carpenter.build()) { error in
            let carpenterError = try XCTUnwrap(error as? CarpenterError)
            XCTAssertEqual(carpenterError, .factoryBuilderHasTooManyArguments(name: "SevenDependenciesObject", count: 7))
        }
    }

    func test_BuildWithLateInit() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Factory(ApiClient.init) { (x: inout ApiClient, k: SixDependenciesObject) in
            x.i = k.i * 3
         })
        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.fourDependenciesObject)
        try carpenter.add(Dependency.fiveDependenciesObject)
        try carpenter.add(Dependency.sixDependenciesObject)

        try await carpenter.build()

        let keychain = try carpenter.get(Dependency.keychain)
        XCTAssertEqual(keychain.i, 10)

        let authClient = try carpenter.get(Dependency.authClient)
        XCTAssertEqual(authClient.i, 20)

        let sixDependencies = try carpenter.get(Dependency.sixDependenciesObject)
        XCTAssertEqual(sixDependencies.i, 7)

        let apiClient = try carpenter.get(Dependency.apiClient)
        XCTAssertEqual(apiClient.i, 21)
    }

    func test_DetectCycles() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.cycleA)
        try carpenter.add(Dependency.cycleB)
        try carpenter.add(Dependency.cycleC)

        try await XCTAssertThrowsAsync(
            try await carpenter.build()
        ) { error in
            let carpenterError = try XCTUnwrap(error as? CarpenterError)
            XCTAssertEqual(carpenterError, .dependencyCyclesDetected(cycles: [
                ["CycleA", "CycleC", "CycleB", "CycleA"]
            ]))
        }
    }

    func test_DetectCyclesInLateInit() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Factory(AuthClient.init) { (_, _: Keychain) in })
        try carpenter.add(Factory(Keychain.init) { (_, _: ApiClient) in })
        try carpenter.add(Factory(ApiClient.init)  { (_, _: AuthClient) in })

        try await XCTAssertThrowsAsync(
            try await carpenter.build()
        ) { error in
            let carpenterError = try XCTUnwrap(error as? CarpenterError)
            XCTAssertEqual(carpenterError, .lateInitCyclesDetected(cycles: [
                ["AuthClient", "ApiClient", "Keychain", "AuthClient"]
            ]))
        }
    }

    func test_DetectDuplicateBuilders() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.keychain)

        try await XCTAssertThrowsAsync(
            try carpenter.add(Dependency.keychain)
        ) { error in
            let carpenterError = try XCTUnwrap(error as? CarpenterError)
            XCTAssertEqual(carpenterError, .factoryAlreadyAdded(name: "Keychain"))
        }
    }
}

func XCTAssertThrowsAsync<T>(
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

func XCTAssertVertexExists(
    _ carpenter: Carpenter,
    name: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssert(carpenter.dependencyGraph.contains(name), "Cannot find vertex \"\(name)\"", file: file, line: line)
}

func XCTAssertEdgeExists(
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


// MARK: - Example implementation

struct Keychain {
    var i: Int
}

struct AuthClient {
    let keychain: Keychain
    var i: Int
}

struct ApiClient {
    let urlSession: URLSession
    let authentication: AuthClient
    var i: Int
}

struct ThreeDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    var i: Int
}

struct FourDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    let threeDependenciesObject: ThreeDependenciesObject
    var i: Int
}

struct FiveDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    let threeDependenciesObject: ThreeDependenciesObject
    let fourDependenciesObject: FourDependenciesObject
    var i: Int
}

struct SixDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    let threeDependenciesObject: ThreeDependenciesObject
    let fourDependenciesObject: FourDependenciesObject
    let fiveDependenciesObject: FiveDependenciesObject
    var i: Int
}

struct SevenDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    let threeDependenciesObject: ThreeDependenciesObject
    let fourDependenciesObject: FourDependenciesObject
    let fiveDependenciesObject: FiveDependenciesObject
    let sixDependenciesObject: FiveDependenciesObject
    var i: Int
}


class CycleA {
    let b: CycleB

    init(b: CycleB) {
        self.b = b
    }
}

class CycleB {
    let c: CycleC

    init(c: CycleC) {
        self.c = c
    }
}

class CycleC {
    let a: CycleA

    init(a: CycleA) {
        self.a = a
    }
}
