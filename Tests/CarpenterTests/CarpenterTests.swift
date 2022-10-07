import XCTest
@testable import Carpenter

enum Dependency {

    static var keychain = Factory(Keychain.init)
    static var authClient = Factory(AuthClient.init)
    static var urlSession = Factory { URLSession.shared }
    static var apiClient = Factory(ApiClient.init)
    static var threeDependenciesObject = Factory(ThreeDependenciesObject.init)
    static var fourDependenciesObject = Factory(FourDependenciesObject.init)
    static var fiveDependenciesObject = Factory(FiveDependenciesObject.init)
    static var sixDependenciesObject = Factory(SixDependenciesObject.init)
    static var sevenDependenciesObject = Factory(SevenDependenciesObject.init)
}

final class CarpenterTests: XCTestCase {

    func test_AddingDependeciesInOrder() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.threeDependenciesObject)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, name: "ApiClient")
        XCTAssertVertexExists(carpenter, name: "NSURLSession")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")
        XCTAssertVertexExists(carpenter, name: "ThreeDependenciesObject")

        XCTAssertEdgeExists(carpenter, from: "NSURLSession", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "ApiClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "ThreeDependenciesObject")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 5)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 6)

        print(carpenter.dependencyGraph.description)
    }

    func test_AddingDependeciesOutOfOrder() throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.keychain)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, name: "ApiClient")
        XCTAssertVertexExists(carpenter, name: "NSURLSession")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")
        XCTAssertVertexExists(carpenter, name: "ThreeDependenciesObject")

        XCTAssertEdgeExists(carpenter, from: "NSURLSession", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "ApiClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "ThreeDependenciesObject")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 5)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 6)

        print(carpenter.dependencyGraph.description)
    }

    func test_BuildProducts() async throws {
        var carpenter = Carpenter()

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
            XCTAssertEqual(carpenterError, .factoryHasTooManyArguments(count: 7))
        }
    }

    func test_DetectDuplicateBuilders() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.keychain)

        try await XCTAssertThrowsAsync(
            try carpenter.add(Dependency.keychain)
        ) { error in
            let carpenterError = try XCTUnwrap(error as? CarpenterError)
            XCTAssertEqual(carpenterError, .dependencyIsAlreadyAdded(name: "Keychain"))
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

}

struct AuthClient {
    let keychain: Keychain
}

struct ApiClient {
    let urlSession: URLSession
    let authentication: AuthClient
}

struct ThreeDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    let keyChain: Keychain
}

struct FourDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    let keyChain: Keychain
    let threeDependenciesObject: ThreeDependenciesObject
}

struct FiveDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    let keyChain: Keychain
    let threeDependenciesObject: ThreeDependenciesObject
    let fourDependenciesObject: FourDependenciesObject
}

struct SixDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    let keyChain: Keychain
    let threeDependenciesObject: ThreeDependenciesObject
    let fourDependenciesObject: FourDependenciesObject
    let fiveDependenciesObject: FiveDependenciesObject
}

struct SevenDependenciesObject {
    let apiClient: ApiClient
    let authClient: AuthClient
    let keyChain: Keychain
    let threeDependenciesObject: ThreeDependenciesObject
    let fourDependenciesObject: FourDependenciesObject
    let fiveDependenciesObject: FiveDependenciesObject
    let sixDependenciesObject: FiveDependenciesObject
}


