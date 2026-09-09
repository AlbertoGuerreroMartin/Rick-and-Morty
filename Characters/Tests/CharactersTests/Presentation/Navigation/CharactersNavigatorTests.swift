//
//  CharactersNavigatorTests.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Testing
@testable import Characters

/// The stack as a value, comparable directly, so navigation is testable without a window or a tap.
@Suite("CharactersNavigator")
@MainActor
struct CharactersNavigatorTests {

    @Test("a new navigator starts at the root")
    func startsEmpty() {
        #expect(CharactersNavigator().path.isEmpty)
    }

    @Test("pushing appends, in the order it was pushed")
    func pushAppends() {
        let navigator = CharactersNavigator()

        navigator.push(.detail(id: "1"))
        navigator.push(.detail(id: "2"))

        #expect(navigator.path == [.detail(id: "1"), .detail(id: "2")])
    }

    @Test("popping removes the last route")
    func popRemovesTheLast() {
        let navigator = CharactersNavigator()
        navigator.push(.detail(id: "1"))
        navigator.push(.detail(id: "2"))

        navigator.pop()

        #expect(navigator.path == [.detail(id: "1")])
    }

    /// `removeLast` on an empty array traps, so this has to be a no-op.
    @Test("popping at the root does nothing")
    func popAtRootIsANoOp() {
        let navigator = CharactersNavigator()

        navigator.pop()

        #expect(navigator.path.isEmpty)
    }

    @Test("popping to the root clears the whole stack")
    func popToRootClears() {
        let navigator = CharactersNavigator()
        navigator.push(.detail(id: "1"))
        navigator.push(.detail(id: "2"))

        navigator.popToRoot()

        #expect(navigator.path.isEmpty)
    }

    @Test("showing a character from the root pushes one detail")
    func showCharacterFromTheRoot() {
        let navigator = CharactersNavigator()

        navigator.showCharacter(id: "42")

        #expect(navigator.path == [.detail(id: "42")])
    }

    /// Replaces the stack: a link arriving while a detail is open lands on the new character, not on top of it.
    @Test("showing a character replaces whatever was on the stack")
    func showCharacterReplacesTheStack() {
        let navigator = CharactersNavigator()
        navigator.push(.detail(id: "1"))
        navigator.push(.detail(id: "2"))

        navigator.showCharacter(id: "42")

        #expect(navigator.path == [.detail(id: "42")])
    }
}
