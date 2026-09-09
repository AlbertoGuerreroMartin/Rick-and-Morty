//
//  DependencyContainerTests.swift
//  Core
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Testing

@testable import Core

@MainActor
private protocol ServiceContract: AnyObject {
    var name: String { get }
}

@MainActor
private final class Service: ServiceContract {
    let name: String

    init(name: String) {
        self.name = name
    }
}

/// Counts how many times a factory ran, so `resolveAll` can be asserted without naming instances.
@MainActor
private final class Counter {
    var count = 0
}

/// Records the container a factory was handed.
@MainActor
private final class ScopeRecorder {
    var scope: DependencyContainer?
}

@Suite("DependencyContainer")
@MainActor
struct DependencyContainerTests {

    @Test("a registration by contract resolves to its implementation")
    func resolvesByContract() {
        let container = DependencyContainer()
        container.register((any ServiceContract).self) { _ in Service(name: "root") }

        #expect(container.resolve((any ServiceContract).self).name == "root")
    }

    @Test("resolving twice hands back the same instance")
    func cachesTheInstance() {
        let container = DependencyContainer()
        container.register((any ServiceContract).self) { _ in Service(name: "root") }

        let first = container.resolve((any ServiceContract).self)
        let second = container.resolve((any ServiceContract).self)

        #expect(first === second)
    }

    @Test("a child falls back to its parent")
    func childFallsBackToTheParent() {
        let root = DependencyContainer()
        root.register((any ServiceContract).self) { _ in Service(name: "root") }
        let child = root.makeChild()

        #expect(child.resolve((any ServiceContract).self) === root.resolve((any ServiceContract).self))
    }

    @Test("a child registration shadows the parent's")
    func childShadowsTheParent() {
        let root = DependencyContainer()
        root.register((any ServiceContract).self) { _ in Service(name: "root") }
        let child = root.makeChild()
        child.register((any ServiceContract).self) { _ in Service(name: "child") }

        #expect(child.resolve((any ServiceContract).self).name == "child")
        #expect(root.resolve((any ServiceContract).self).name == "root")
    }

    /// The point of resolving through the child: a root registration is a singleton for the tree.
    @Test("two children share what the root registered")
    func childrenShareTheRootInstance() {
        let root = DependencyContainer()
        root.register((any ServiceContract).self) { _ in Service(name: "root") }

        let first = root.makeChild().resolve((any ServiceContract).self)
        let second = root.makeChild().resolve((any ServiceContract).self)

        #expect(first === second)
    }

    @Test("registering again replaces the factory and drops the cached instance")
    func reRegistrationReplacesTheInstance() {
        let container = DependencyContainer()
        container.register((any ServiceContract).self) { _ in Service(name: "first") }
        let first = container.resolve((any ServiceContract).self)

        container.register((any ServiceContract).self) { _ in Service(name: "second") }
        let second = container.resolve((any ServiceContract).self)

        #expect(first !== second)
        #expect(second.name == "second")
    }

    @Test("resolveAll instantiates every registration in the tree")
    func resolveAllInstantiatesEverything() {
        let counter = Counter()
        let root = DependencyContainer()
        root.register(Counter.self) { _ in counter }
        root.register((any ServiceContract).self) { scope in
            scope.resolve(Counter.self).count += 1
            return Service(name: "root")
        }
        let child = root.makeChild()
        child.register(Service.self) { scope in
            scope.resolve(Counter.self).count += 1
            return Service(name: "child")
        }

        child.resolveAll()

        #expect(counter.count == 2)
    }

    @Test("a scoped registration gives each child its own instance")
    func scopedGivesEachChildItsOwn() {
        let root = DependencyContainer()
        root.register((any ServiceContract).self, lifetime: .scoped) { _ in Service(name: "scoped") }

        let first = root.makeChild().resolve((any ServiceContract).self)
        let second = root.makeChild().resolve((any ServiceContract).self)

        #expect(first !== second)
    }

    @Test("a scoped registration resolves once within one child")
    func scopedCachesWithinTheChild() {
        let root = DependencyContainer()
        root.register((any ServiceContract).self, lifetime: .scoped) { _ in Service(name: "scoped") }
        let child = root.makeChild()

        #expect(child.resolve((any ServiceContract).self) === child.resolve((any ServiceContract).self))
    }

    @Test("a scoped factory picks up the shared singleton it depends on")
    func scopedResolvesTheSharedSingleton() {
        let root = DependencyContainer()
        root.register(Counter.self) { _ in Counter() }
        root.register((any ServiceContract).self, lifetime: .scoped) { scope in
            scope.resolve(Counter.self).count += 1
            return Service(name: "scoped")
        }

        _ = root.makeChild().resolve((any ServiceContract).self)
        _ = root.makeChild().resolve((any ServiceContract).self)

        #expect(root.resolve(Counter.self).count == 2)
    }

    @Test("registering a scoped key again drops that child's cached instance")
    func reRegistrationDropsTheScopedInstance() {
        let root = DependencyContainer()
        root.register((any ServiceContract).self, lifetime: .scoped) { _ in Service(name: "root") }
        let child = root.makeChild()
        let first = child.resolve((any ServiceContract).self)

        child.register((any ServiceContract).self, lifetime: .scoped) { _ in Service(name: "child") }
        let second = child.resolve((any ServiceContract).self)
        child.register((any ServiceContract).self, lifetime: .scoped) { _ in Service(name: "again") }

        #expect(first !== second)
        #expect(second.name == "child")
        #expect(child.resolve((any ServiceContract).self).name == "again")
    }

    @Test("a factory is handed the container it is resolving through")
    func factoryReceivesTheResolvingContainer() {
        let recorder = ScopeRecorder()
        let root = DependencyContainer()
        root.register(ScopeRecorder.self) { scope in
            recorder.scope = scope
            return recorder
        }
        let child = root.makeChild()

        _ = child.resolve(ScopeRecorder.self)

        #expect(recorder.scope === child)
    }
}
