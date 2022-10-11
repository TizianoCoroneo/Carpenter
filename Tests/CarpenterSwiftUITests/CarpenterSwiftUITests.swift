import XCTest
import CarpenterTestUtilities
@testable import CarpenterSwiftUI

import SwiftUI

struct ApiClientEnvironementKey: CarpenterEnvironmentKey {
    static let key = DependencyKey<ApiClient>()
}

extension EnvironmentValues {
    var apiClient: ApiClient {
        get { self[ApiClientEnvironementKey.self] }
        set { self[ApiClientEnvironementKey.self] = newValue }
    }
}

final class CarpenterSwiftUITests: XCTestCase {

    override func setUp() {
        Carpenter.shared = .init()
    }

    override func tearDown() {
        Carpenter.shared = .init()
    }

    func testGetProductFromEnvironmentDefault() async throws {
        Carpenter.shared = try .init {
            Dependency.i
            Dependency.keychain
            Dependency.authClient
            Dependency.urlSession
            Dependency.apiClient
        }

        try Carpenter.shared.build()

        _ = Environment(\.apiClient).wrappedValue
    }

}
