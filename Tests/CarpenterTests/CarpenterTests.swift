import XCTest
import CarpenterTestUtilities
@testable import Carpenter

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
        XCTAssertVertexExists(carpenter, name: "Session")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")
        XCTAssertVertexExists(carpenter, name: "ThreeDependenciesObject")

        XCTAssertEdgeExists(carpenter, from: "Int", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "Keychain")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "Session", to: "ApiClient")
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
        XCTAssertVertexExists(carpenter, name: "Session")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")
        XCTAssertVertexExists(carpenter, name: "ThreeDependenciesObject")

        XCTAssertEdgeExists(carpenter, from: "Int", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "Keychain")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "Session", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "ApiClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ThreeDependenciesObject")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 6)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 9)

        print(carpenter.dependencyGraph.description)
    }

    func test_NotStartStartupTasksBeforeBuldingGraph() async throws {
        var carpenter = Carpenter()

        let exp1 = expectation(description: "Should not complete start up task 1 before building the graph")
        exp1.isInverted = true
        let exp2 = expectation(description: "Should not complete start up task 2 before building the graph")
        exp2.isInverted = true
        let exp3 = expectation(description: "Should not complete start up task 3 before building the graph")
        exp3.isInverted = true

        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.startupTask1(exp: exp1))
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.startupTask2(exp: exp2))
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.startupTask3(exp: exp3))
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.i)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, name: "Int")
        XCTAssertVertexExists(carpenter, name: "ApiClient")
        XCTAssertVertexExists(carpenter, name: "Session")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")
        XCTAssertVertexExists(carpenter, name: "ThreeDependenciesObject")
        XCTAssertVertexExists(carpenter, name: "Task 1")
        XCTAssertVertexExists(carpenter, name: "Task 2")
        XCTAssertVertexExists(carpenter, name: "Task 3")

        XCTAssertEdgeExists(carpenter, from: "Int", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "Keychain")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "Session", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "ApiClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "ApiClient", to: "Task 1")
        XCTAssertEdgeExists(carpenter, from: "Session", to: "Task 2")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "Task 3")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 9)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 12)

        print(carpenter.dependencyGraph.description)

        await waitForExpectations(timeout: 0.2)
    }

    func test_AddingStartupTasksMixedIn() async throws {
        var carpenter = Carpenter()

        let exp1 = expectation(description: "Completes start up task 1 when building the graph")
        let exp2 = expectation(description: "Completes start up task 2 when building the graph")
        let exp3 = expectation(description: "Completes start up task 3 when building the graph")

        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.startupTask1(exp: exp1))
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.startupTask2(exp: exp2))
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.startupTask3(exp: exp3))
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.i)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, name: "Int")
        XCTAssertVertexExists(carpenter, name: "ApiClient")
        XCTAssertVertexExists(carpenter, name: "Session")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")
        XCTAssertVertexExists(carpenter, name: "ThreeDependenciesObject")
        XCTAssertVertexExists(carpenter, name: "Task 1")
        XCTAssertVertexExists(carpenter, name: "Task 2")
        XCTAssertVertexExists(carpenter, name: "Task 3")

        XCTAssertEdgeExists(carpenter, from: "Int", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "Keychain")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "Session", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Keychain", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "ApiClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "ApiClient", to: "Task 1")
        XCTAssertEdgeExists(carpenter, from: "Session", to: "Task 2")
        XCTAssertEdgeExists(carpenter, from: "AuthClient", to: "Task 3")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 9)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 12)

        try await carpenter.build()

        await waitForExpectations(timeout: 0.2)

        print(carpenter.dependencyGraph.description)
    }

    func test_AddingDependeciesWithFactoryBuilder() throws {
        let carpenter = try Carpenter {
            Dependency.threeDependenciesObject
            Dependency.apiClient
            Dependency.urlSession
            Dependency.authClient
            Dependency.keychain
            Dependency.i
        }

        XCTAssertVertexExists(carpenter, name: "Int")
        XCTAssertVertexExists(carpenter, name: "ApiClient")
        XCTAssertVertexExists(carpenter, name: "Session")
        XCTAssertVertexExists(carpenter, name: "AuthClient")
        XCTAssertVertexExists(carpenter, name: "Keychain")
        XCTAssertVertexExists(carpenter, name: "ThreeDependenciesObject")

        XCTAssertEdgeExists(carpenter, from: "Int", to: "ApiClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "AuthClient")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "Keychain")
        XCTAssertEdgeExists(carpenter, from: "Int", to: "ThreeDependenciesObject")
        XCTAssertEdgeExists(carpenter, from: "Session", to: "ApiClient")
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
        let _: Session = try carpenter.get(Dependency.urlSession)
        let _: AuthClient = try carpenter.get(Dependency.authClient)
        let _: ThreeDependenciesObject = try carpenter.get(Dependency.threeDependenciesObject)
    }

    func test_BuildProductsWithResultBuilder() async throws {
        var carpenter = try Carpenter {
            Dependency.i
            Dependency.threeDependenciesObject
            Dependency.apiClient
            Dependency.urlSession
            Dependency.authClient
            Dependency.keychain
        }

        try await carpenter.build()

        let _: Keychain = try carpenter.get(Dependency.keychain)
        let _: AuthClient = try carpenter.get(Dependency.authClient)
        let _: Session = try carpenter.get(Dependency.urlSession)
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
        let _: Session = try carpenter.get(Dependency.urlSession)
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
