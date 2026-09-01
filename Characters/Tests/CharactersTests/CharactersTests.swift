import Testing
@testable import Characters

@Test @MainActor func charactersViewInitializes() async throws {
    _ = CharactersView()
}
