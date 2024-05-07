import XCTest
import CarpenterTestUtilities
import os.log
@testable import Carpenter

@available(iOS 17, macOS 14, *)
final class CarpenterTests: XCTestCase {

    let logger = Logger(subsystem: "com.tiziano.carpenter.tests", category: "Carpenter Tests")

    func test_AddingDependeciesInOrder() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.threeDependenciesObject)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, type: Int.self)
        XCTAssertVertexExists(carpenter, type: ApiClient.self)
        XCTAssertVertexExists(carpenter, type: Session.self)
        XCTAssertVertexExists(carpenter, type: AuthClient.self)
        XCTAssertVertexExists(carpenter, type: Keychain.self)
        XCTAssertVertexExists(carpenter, type: ThreeDependenciesObject.self)

        XCTAssertEdgeExists(carpenter, from: Int.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: Keychain.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: Session.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Keychain.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: ApiClient.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ThreeDependenciesObject.self)

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

        XCTAssertVertexExists(carpenter, type: Int.self)
        XCTAssertVertexExists(carpenter, type: ApiClient.self)
        XCTAssertVertexExists(carpenter, type: Session.self)
        XCTAssertVertexExists(carpenter, type: AuthClient.self)
        XCTAssertVertexExists(carpenter, type: Keychain.self)
        XCTAssertVertexExists(carpenter, type: ThreeDependenciesObject.self)

        XCTAssertEdgeExists(carpenter, from: Int.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: Keychain.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: Session.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Keychain.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: ApiClient.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ThreeDependenciesObject.self)

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

        XCTAssertVertexExists(carpenter, type: Int.self)
        XCTAssertVertexExists(carpenter, type: ApiClient.self)
        XCTAssertVertexExists(carpenter, type: Session.self)
        XCTAssertVertexExists(carpenter, type: AuthClient.self)
        XCTAssertVertexExists(carpenter, type: Keychain.self)
        XCTAssertVertexExists(carpenter, type: ThreeDependenciesObject.self)
        XCTAssertVertexExists(carpenter, name: "Task 1")
        XCTAssertVertexExists(carpenter, name: "Task 2")
        XCTAssertVertexExists(carpenter, name: "Task 3")

        XCTAssertEdgeExists(carpenter, from: Int.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: Keychain.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: Session.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Keychain.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: ApiClient.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: ApiClient.self, to: "Task 1")
        XCTAssertEdgeExists(carpenter, from: Session.self, to: "Task 2")
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: "Task 3")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 9)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 12)

        print(carpenter.dependencyGraph.description)

        await fulfillment(of: [exp1, exp2, exp3], timeout: 0.2)
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
        try carpenter.add(Dependency.authLateInit)
        try carpenter.add(Dependency.startupTask3(exp: exp3))
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.keychainLateInit)
        try carpenter.add(Dependency.i)

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, type: Int.self)
        XCTAssertVertexExists(carpenter, type: ApiClient.self)
        XCTAssertVertexExists(carpenter, type: Session.self)
        XCTAssertVertexExists(carpenter, type: AuthClient.self)
        XCTAssertVertexExists(carpenter, type: Keychain.self)
        XCTAssertVertexExists(carpenter, type: ThreeDependenciesObject.self)
        XCTAssertVertexExists(carpenter, name: "Task 1")
        XCTAssertVertexExists(carpenter, name: "Task 2")
        XCTAssertVertexExists(carpenter, name: "Task 3")

        XCTAssertEdgeExists(carpenter, from: Int.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: Keychain.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: Session.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Keychain.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: ApiClient.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: ApiClient.self, to: "Task 1")
        XCTAssertEdgeExists(carpenter, from: Session.self, to: "Task 2")
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: "Task 3")

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 9)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 12)

        try carpenter.build()

        await fulfillment(of: [exp1, exp2, exp3], timeout: 0.2)

        print(carpenter.dependencyGraph.description)
    }

    func test_AddingDependeciesWithFactoryBuilder() throws {
        var carpenter = try Carpenter {
            Dependency.threeDependenciesObject
            Dependency.apiClient
            Dependency.urlSession
            Dependency.authClient
            Dependency.keychain
            Dependency.i
        }

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, type: Int.self)
        XCTAssertVertexExists(carpenter, type: ApiClient.self)
        XCTAssertVertexExists(carpenter, type: Session.self)
        XCTAssertVertexExists(carpenter, type: AuthClient.self)
        XCTAssertVertexExists(carpenter, type: Keychain.self)
        XCTAssertVertexExists(carpenter, type: ThreeDependenciesObject.self)

        XCTAssertEdgeExists(carpenter, from: Int.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: Keychain.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: Session.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Keychain.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: ApiClient.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ThreeDependenciesObject.self)

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 6)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 9)

        print(carpenter.dependencyGraph.description)
    }

    func test_AddingDependeciesWithFactoryBuilderWithArray() throws {
        var carpenter = try Carpenter {
            [
                Dependency.threeDependenciesObject.eraseToAnyFactory(),
                Dependency.apiClient.eraseToAnyFactory(),
                Dependency.urlSession.eraseToAnyFactory()
            ].flatMap { $0 }
            [
                Dependency.authClient.eraseToAnyFactory(),
                Dependency.keychain.eraseToAnyFactory(),
                Dependency.i.eraseToAnyFactory()
            ].flatMap { $0 }
        }

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, type: Int.self)
        XCTAssertVertexExists(carpenter, type: ApiClient.self)
        XCTAssertVertexExists(carpenter, type: Session.self)
        XCTAssertVertexExists(carpenter, type: AuthClient.self)
        XCTAssertVertexExists(carpenter, type: Keychain.self)
        XCTAssertVertexExists(carpenter, type: ThreeDependenciesObject.self)

        XCTAssertEdgeExists(carpenter, from: Int.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: Keychain.self)
        XCTAssertEdgeExists(carpenter, from: Int.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: Session.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ApiClient.self)
        XCTAssertEdgeExists(carpenter, from: Keychain.self, to: AuthClient.self)
        XCTAssertEdgeExists(carpenter, from: ApiClient.self, to: ThreeDependenciesObject.self)
        XCTAssertEdgeExists(carpenter, from: AuthClient.self, to: ThreeDependenciesObject.self)

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 6)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 9)

        print(carpenter.dependencyGraph.description)
    }

    func test_AddingDependeciesWithGenericTypes() throws {
        var carpenter = try Carpenter {
            Dependency.array
            Dependency.dictionary
            Dependency.consumeArrayAndDictionary
        }

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, type: Array<Int>.self)
        XCTAssertVertexExists(carpenter, type: Dictionary<String, Int>.self)
        XCTAssertVertexExists(carpenter, type: Dependency.TestGeneric<Array<Int>, Dictionary<String, Int>>.self)

        XCTAssertEdgeExists(carpenter, from: Array<Int>.self, to: Dependency.TestGeneric<Array<Int>, Dictionary<String, Int>>.self)
        XCTAssertEdgeExists(carpenter, from: Dictionary<String, Int>.self, to: Dependency.TestGeneric<Array<Int>, Dictionary<String, Int>>.self)

        XCTAssertEqual(carpenter.dependencyGraph.vertexCount, 3)
        XCTAssertEqual(carpenter.dependencyGraph.edgeCount, 2)

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

        try carpenter.build()

        let _: Keychain = try carpenter.get(Dependency.keychain)
        let _: AuthClient = try carpenter.get(Dependency.authClient)
        let _: Session = try carpenter.get(Dependency.urlSession)
        let _: AuthClient = try carpenter.get(Dependency.authClient)
        let _: ThreeDependenciesObject = try carpenter.get(Dependency.threeDependenciesObject)
    }

    func test_BuildProductsInTwoPhases() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.authClient)

        try carpenter.build()

        let keychain = try carpenter.get(Dependency.keychain)
        let authClient = try carpenter.get(Dependency.authClient)

        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.threeDependenciesObject)

        try carpenter.build()

        let keychain2 = try carpenter.get(Dependency.keychain)
        let authClient2 = try carpenter.get(Dependency.authClient)

        // Keychain and authClient do not get rebuilt
        XCTAssertIdentical(keychain, keychain2)
        XCTAssertIdentical(authClient, authClient2)

        let _: Session = try carpenter.get(Dependency.urlSession)
        let _: AuthClient = try carpenter.get(Dependency.authClient)
        let _: ThreeDependenciesObject = try carpenter.get(Dependency.threeDependenciesObject)
    }

    func test_BuildProductsInTwoPhasesWithResultBuilder() async throws {
        var carpenter = try Carpenter {
            Dependency.i
            Dependency.keychain
            Dependency.authClient
        }

        try carpenter.build()

        let keychain = try carpenter.get(Dependency.keychain)
        let authClient = try carpenter.get(Dependency.authClient)

        try carpenter.add {
            Dependency.urlSession
            Dependency.apiClient
            Dependency.threeDependenciesObject
        }

        try carpenter.build()

        let keychain2 = try carpenter.get(Dependency.keychain)
        let authClient2 = try carpenter.get(Dependency.authClient)

        // Keychain and authClient do not get rebuilt
        XCTAssertIdentical(keychain, keychain2)
        XCTAssertIdentical(authClient, authClient2)

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

        try carpenter.build()

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
        try carpenter.build()

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

        try carpenter.build()

        blackHole(try carpenter.get(Dependency.keychain))
        blackHole(try carpenter.get(Dependency.authClient))
        blackHole(try carpenter.get(Dependency.urlSession))
        blackHole(try carpenter.get(Dependency.apiClient))
        blackHole(try carpenter.get(Dependency.threeDependenciesObject))
        blackHole(try carpenter.get(Dependency.fourDependenciesObject))
        blackHole(try carpenter.get(Dependency.fiveDependenciesObject))
        blackHole(try carpenter.get(Dependency.sixDependenciesObject))
    }

    func test_BuildWithLateInit() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.keychainLateInit) // This doesn't run because the system thinks the requirement array is empty. Fix carpenter.add(_ factory:) !
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.authLateInit)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Factory(ApiClient.init))
        try carpenter.add(LateInit { (x: inout ApiClient, k: SixDependenciesObject) in
            x.i = k.i * 3
         })

        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.fourDependenciesObject)
        try carpenter.add(Dependency.fiveDependenciesObject)
        try carpenter.add(Dependency.fiveDependenciesObjectLateInit)
        try carpenter.add(Dependency.sixDependenciesObject)
        try carpenter.add(Dependency.sixDependenciesObjectLateInit)

        try carpenter.build()

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
            try carpenter.build()
        ) { error in
            let carpenterError = try XCTUnwrap(error as? CarpenterError)
            XCTAssertEqual(carpenterError, .dependencyCyclesDetected(cycles: [
                [.init(CycleA.self), .init(CycleC.self), .init(CycleB.self), .init(CycleA.self)]
            ]))
        }
    }

    func test_DetectCyclesInLateInit() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Factory(AuthClient.init))
        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(LateInit { (_: AuthClient, _: Keychain) in })
        try carpenter.add(LateInit { (_: Keychain, _: ApiClient) in })
        try carpenter.add(LateInit { (_: ApiClient, _: AuthClient) in })

        try await XCTAssertThrowsAsync(
            try carpenter.build()
        ) { error in
            let carpenterError = try XCTUnwrap(error as? CarpenterError)
            XCTAssertEqual(carpenterError, .lateInitCyclesDetected(cycles: [
                [.init(AuthClient.self), .init(ApiClient.self), .init(Keychain.self), .init(AuthClient.self)]
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
            XCTAssertEqual(carpenterError, .factoryAlreadyAdded(name: .init(Keychain.self)))
        }
    }

    func test_ProfileLargeProject() throws {
        let signposter = OSSignposter(logger: logger)

        for _ in 0..<300 {
            let id = signposter.makeSignpostID()
            signposter.withIntervalSignpost("Running Carpenter", id: id) {
                let generatedByCarpenter = GeneratedByCarpenter()

                let c = signposter.withIntervalSignpost("Creating container", id: id) {
                    generatedByCarpenter.makeContainer()
                }

                signposter.withIntervalSignpost("Accessing container") {
                    generatedByCarpenter.accessAllInContainer(c)
                }
            }
        }
    }

    func test_BenchmarkLargeProjectInXcode() throws {
        let signposter = OSSignposter(logger: logger)

        self.measure {
            for _ in 0..<300 {
                let id = signposter.makeSignpostID()
                signposter.withIntervalSignpost("Running Carpenter", id: id) {
                    let generatedByCarpenter = GeneratedByCarpenter()

                    let c = signposter.withIntervalSignpost("Creating container", id: id) {
                        generatedByCarpenter.makeContainer()
                    }

                    signposter.withIntervalSignpost("Accessing container") {
                        generatedByCarpenter.accessAllInContainer(c)
                    }
                }
            }
        }
    }
}

@available(iOS 17, macOS 14, *)
extension Dependency {
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


public func XCTAssertVertexExists<T>(
    _ carpenter: Carpenter,
    type: T.Type = T.self,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssert(carpenter.dependencyGraph.contains(.init(type)), "Cannot find vertex \"\(type)\"", file: file, line: line)
}


public func XCTAssertVertexExists(
    _ carpenter: Carpenter,
    name: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssert(carpenter.dependencyGraph.contains(AnyDependencyKey(name: name)), "Cannot find vertex \"\(name)\"", file: file, line: line)
}


public func XCTAssertEdgeExists<T, U>(
    _ carpenter: Carpenter,
    from: T.Type = T.self,
    to: U.Type = U.self,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(
        carpenter.dependencyGraph.edgeExists(
            from: .init(from),
            to: .init(to)),
        "Cannot find edge from \"\(from)\" to \"\(to)\"",
        file: file,
        line: line)
}


public func XCTAssertEdgeExists<T>(
    _ carpenter: Carpenter,
    from: T.Type = T.self,
    to: String,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertTrue(
        carpenter.dependencyGraph.edgeExists(
            from: .init(from),
            to: .init(name: to)),
        "Cannot find edge from \"\(from)\" to \"\(to)\"",
        file: file,
        line: line)
}
