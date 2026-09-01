import Testing
@testable import Episodes

@Test @MainActor func episodesViewInitializes() async throws {
    _ = EpisodesView()
}
