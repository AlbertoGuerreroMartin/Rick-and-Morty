//
//  EpisodesNavigatorTests.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Testing
@testable import Episodes

@Suite("EpisodesNavigator")
@MainActor
struct EpisodesNavigatorTests {

    @Test("a new navigator starts at the root")
    func startsEmpty() {
        #expect(EpisodesNavigator().path.isEmpty)
    }

    @Test("pushing appends, in the order it was pushed")
    func pushAppends() {
        let navigator = EpisodesNavigator()

        navigator.push(.character(id: "1"))
        navigator.push(.character(id: "2"))

        #expect(navigator.path == [.character(id: "1"), .character(id: "2")])
    }

    @Test("popping removes the last route")
    func popRemovesTheLast() {
        let navigator = EpisodesNavigator()
        navigator.push(.character(id: "1"))
        navigator.push(.character(id: "2"))

        navigator.pop()

        #expect(navigator.path == [.character(id: "1")])
    }

    @Test("popping at the root does nothing")
    func popAtRootIsANoOp() {
        let navigator = EpisodesNavigator()

        navigator.pop()

        #expect(navigator.path.isEmpty)
    }

    @Test("popping to the root clears the whole stack")
    func popToRootClears() {
        let navigator = EpisodesNavigator()
        navigator.push(.character(id: "1"))
        navigator.push(.character(id: "2"))

        navigator.popToRoot()

        #expect(navigator.path.isEmpty)
    }

    @Test("showing a character from the root pushes one character")
    func showCharacterFromTheRoot() {
        let navigator = EpisodesNavigator()

        navigator.showCharacter(id: "42")

        #expect(navigator.path == [.character(id: "42")])
    }

    @Test("showing a character appends rather than replacing the stack")
    func showCharacterAppends() {
        let navigator = EpisodesNavigator()
        navigator.push(.character(id: "1"))

        navigator.showCharacter(id: "42")

        #expect(navigator.path == [.character(id: "1"), .character(id: "42")])
    }
}
