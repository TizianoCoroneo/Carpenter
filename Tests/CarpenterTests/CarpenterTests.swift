import XCTest
import CarpenterTestUtilities
import os.log
@testable import Carpenter

final class CarpenterTests: XCTestCase {

    func test_splitRequirements_simple() throws {
        let test = "ApiClient"
        let splitted = splitTupleContent(test)
        XCTAssertEqual(splitted, ["ApiClient"])
    }

    func test_splitRequirements_array() throws {
        let test = "[ApiClient]"
        let splitted = splitTupleContent(test)
        XCTAssertEqual(splitted, ["[ApiClient]"])
    }

    func test_splitRequirements_dictionary() throws {
        let test = "[ApiClient: String]"
        let splitted = splitTupleContent(test)
        XCTAssertEqual(splitted, ["[ApiClient: String]"])
    }

    func test_splitRequirements_tuple() throws {
        let test = "(String, Int)"
        let splitted = splitTupleContent(test)
        XCTAssertEqual(splitted, ["String", "Int"])
    }

    func test_splitRequirements_nestedTuple() throws {
        let test = "((String, Int), (String, Double))"
        let splitted = splitTupleContent(test)
        XCTAssertEqual(splitted, ["(String, Int)", "(String, Double)"])
    }

    func test_splitRequirements_complexType() throws {
        let test = "(Dictionary[String: (String, Int)], Dictionary[(String, Int): Double], Array[(Int, Int, Int)])"
        let splitted = splitTupleContent(test)
        XCTAssertEqual(splitted, ["Dictionary[String: (String, Int)]", "Dictionary[(String, Int): Double]", "Array[(Int, Int, Int)]"])
    }

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

    func test_AddingDependeciesWithGenericTypes() throws {
        var carpenter = try Carpenter {
            Dependency.array
            Dependency.dictionary
            Dependency.consumeArrayAndDictionary
        }

        try carpenter.finalizeGraph()

        XCTAssertVertexExists(carpenter, name: "Array<Int>")
        XCTAssertVertexExists(carpenter, name: "Dictionary<String, Int>")
        XCTAssertVertexExists(carpenter, name: "TestGeneric<Array<Int>, Dictionary<String, Int>>")

        XCTAssertEdgeExists(carpenter, from: "Array<Int>", to: "TestGeneric<Array<Int>, Dictionary<String, Int>>")
        XCTAssertEdgeExists(carpenter, from: "Dictionary<String, Int>", to: "TestGeneric<Array<Int>, Dictionary<String, Int>>")

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

    func test_BuildTooBigProducts() async throws {
        var carpenter = Carpenter()

        try carpenter.add(Dependency.i)
        try carpenter.add(Dependency.a)
        try carpenter.add(Dependency.b)
        try carpenter.add(Dependency.c)
        try carpenter.add(Dependency.d)
        try carpenter.add(Dependency.e)
        try carpenter.add(Dependency.f)
        try carpenter.add(Dependency.g)
        try carpenter.add(Dependency.h)
        try carpenter.add(Dependency.i2)
        try carpenter.add(Dependency.j)

        try carpenter.add(Dependency.keychain)
        try carpenter.add(Dependency.authClient)
        try carpenter.add(Dependency.urlSession)
        try carpenter.add(Dependency.apiClient)
        try carpenter.add(Dependency.threeDependenciesObject)
        try carpenter.add(Dependency.fourDependenciesObject)
        try carpenter.add(Dependency.fiveDependenciesObject)
        try carpenter.add(Dependency.sixDependenciesObject)
        try carpenter.add(Dependency.sixteenDependenciesObject)

        try await XCTAssertThrowsAsync(try carpenter.build()) { error in
            let carpenterError = try XCTUnwrap(error as? CarpenterError)
            XCTAssertEqual(carpenterError, .factoryBuilderHasTooManyArguments(name: "SixteenDependenciesObject", count: 16))
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
            try carpenter.build()
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

    func test_BenchmarkSplitTupleContent() throws {
        let tuples: [Any.Type] = Array.init(repeating: [
            Void.self,
            (Int).self,
            (Int, String).self,
            (Int, String, Bool).self,
            (Int, String, Bool, UInt8).self,
        ], count: 10000).flatMap { $0 }

        let tupleStrings = tuples.map { String(describing: $0) }
        print(tupleStrings)

        self.measure {
            for tupleString in tupleStrings {
                blackHole(splitTupleContent(tupleString))
            }
        }
    }

    func test_BenchmarkLargeProject() throws {
        let logger = Logger.init(subsystem: "com.measure-tests", category: "Measuring tests")
        let signposter = OSSignposter(logger: logger)

        self.measure {
            for _ in 0..<30 {
                let id = signposter.makeSignpostID()
                signposter.withIntervalSignpost("Running Carpenter", id: id) {
                    let generatedByCarpenter = GeneratedByCarpenter()
                    let c = generatedByCarpenter.makeContainer()
                    signposter.emitEvent("Accessing container", id: id)
                    generatedByCarpenter.accessAllInContainer(c)
                }
            }
        }
    }
}

@_optimize(none)
func blackHole(_ value: Any) {}
