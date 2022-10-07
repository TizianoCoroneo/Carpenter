import XCTest
@testable import Carpenter

final class CarpenterTests: XCTestCase {

    let urlSessionRecipy: () -> URLSession = {
        URLSession.shared
    }

    let threeDependencyObjectRecipy = ThreeDependenciesObject.init

    func test_AddingDependeciesInOrder() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Keychain.init)
        try carpenter.add(AuthClient.init)
        try carpenter.add(urlSessionRecipy)
        try carpenter.add(ApiClient.init)
        try carpenter.add(ThreeDependenciesObject.init)

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

        try carpenter.add(ThreeDependenciesObject.init)
        try carpenter.add(ApiClient.init)
        try carpenter.add(urlSessionRecipy)
        try carpenter.add(AuthClient.init)
        try carpenter.add(Keychain.init)

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

        try carpenter.add(ThreeDependenciesObject.init)
        try carpenter.add(ApiClient.init)
        try carpenter.add(urlSessionRecipy)
        try carpenter.add(AuthClient.init)
        try carpenter.add(Keychain.init)

        try await carpenter.build()

        _ = try carpenter.get(Keychain.self)
        _ = try carpenter.get(AuthClient.self)
        _ = try carpenter.get(URLSession.self)
        _ = try carpenter.get(ApiClient.self)
        _ = try carpenter.get(ThreeDependenciesObject.self)
    }

    func test_FinalizeAndBuildProducts() async throws {
        var carpenter = Carpenter()

        try carpenter.add(ThreeDependenciesObject.init)
        try carpenter.add(ApiClient.init)
        try carpenter.add(urlSessionRecipy)
        try carpenter.add(AuthClient.init)
        try carpenter.add(Keychain.init)

        try carpenter.finalizeGraph()
        try await carpenter.build()

        _ = try carpenter.get(Keychain.self)
        _ = try carpenter.get(AuthClient.self)
        _ = try carpenter.get(URLSession.self)
        _ = try carpenter.get(ApiClient.self)
        _ = try carpenter.get(ThreeDependenciesObject.self)
    }

    func test_BuildBigProducts() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Keychain.init)
        try carpenter.add(AuthClient.init)
        try carpenter.add(urlSessionRecipy)
        try carpenter.add(ApiClient.init)
        try carpenter.add(ThreeDependenciesObject.init)
        try carpenter.add(FourDependenciesObject.init)
        try carpenter.add(FiveDependenciesObject.init)
        try carpenter.add(SixDependenciesObject.init)

        try await carpenter.build()

        _ = try carpenter.get(Keychain.self)
        _ = try carpenter.get(AuthClient.self)
        _ = try carpenter.get(URLSession.self)
        _ = try carpenter.get(ApiClient.self)
        _ = try carpenter.get(ThreeDependenciesObject.self)
        _ = try carpenter.get(FourDependenciesObject.self)
        _ = try carpenter.get(FiveDependenciesObject.self)
        _ = try carpenter.get(SixDependenciesObject.self)
    }

    func test_BuildTooBigProducts() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Keychain.init)
        try carpenter.add(AuthClient.init)
        try carpenter.add(urlSessionRecipy)
        try carpenter.add(ApiClient.init)
        try carpenter.add(ThreeDependenciesObject.init)
        try carpenter.add(FourDependenciesObject.init)
        try carpenter.add(FiveDependenciesObject.init)
        try carpenter.add(SixDependenciesObject.init)
        try carpenter.add(SevenDependenciesObject.init)

        try await XCTAssertThrowsAsync(try await carpenter.build()) { error in
            let carpenterError = try XCTUnwrap(error as? CarpenterError)
            XCTAssertEqual(carpenterError, .dependencyBuilderHasTooManyArguments(count: 7))
        }
    }

    func test_DetectDuplicateBuilders() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Keychain.init)

        try await XCTAssertThrowsAsync(
            try carpenter.add(Keychain.init)
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


