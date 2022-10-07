import XCTest
@testable import Carpenter

final class CarpenterTests: XCTestCase {

    let keychainRecipy: () -> Keychain = {
        Keychain()
    }

    let authClientRecipy: (Keychain) -> AuthClient = {
        AuthClient(keychain: $0)
    }

    let urlSessionRecipy: () -> URLSession = {
        URLSession.shared
    }

    let apiClientRecipy: (URLSession, AuthClient) -> ApiClient = {
        ApiClient(urlSession: $0, authentication: $1)
    }


    func test_AddingDependeciesInOrder() async throws {
        var carpenter = Carpenter()

        try carpenter.add(keychainRecipy)
        try carpenter.add(authClientRecipy)
        try carpenter.add(urlSessionRecipy)
        try carpenter.add(apiClientRecipy)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, name: "ApiClient")
        XCTAssertVertexExists(carpenter, name: "NSURLSession")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")

        XCTAssertEdgeExists(carpenter, from: "NSURLSession", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "AuthClient")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 4)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 3)

        print(carpenter.dependencyGraph.description)
    }

    func test_AddingDependeciesOutOfOrder() throws {
        var carpenter = Carpenter()

        try carpenter.add(keychainRecipy)
        try carpenter.add(authClientRecipy)
        try carpenter.add(urlSessionRecipy)
        try carpenter.add(apiClientRecipy)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, name: "ApiClient")
        XCTAssertVertexExists(carpenter, name: "NSURLSession")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")

        XCTAssertEdgeExists(carpenter, from: "NSURLSession", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "AuthClient")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 4)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 3)

        print(carpenter.dependencyGraph.description)
    }

    func test_BuildProducts() async throws {
        var carpenter = Carpenter()

        try carpenter.add(keychainRecipy)
        try carpenter.add(authClientRecipy)
        try carpenter.add(urlSessionRecipy)
        try carpenter.add(apiClientRecipy)

        try await carpenter.build()

        _ = try carpenter.get(Keychain.self)
        _ = try carpenter.get(AuthClient.self)
        _ = try carpenter.get(URLSession.self)
        _ = try carpenter.get(ApiClient.self)
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




