import Testing
@testable import Locations

@Test @MainActor func locationsViewInitializes() async throws {
    _ = LocationsView()
}
