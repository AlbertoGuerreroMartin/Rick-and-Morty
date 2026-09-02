import Testing
@testable import Networking

@Test func apiClientInitializes() async throws {
    _ = APIClient()
}
