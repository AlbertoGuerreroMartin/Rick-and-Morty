//
//  DependencyContainer.swift
//  Core
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

/// How long a resolved instance lives.
public enum DependencyLifetime: Sendable {
    /// One instance in the container holding the registration, shared by every child below it.
    case singleton
    /// One instance per container resolved through, so each child scope gets its own.
    case scoped
}

/// Registration and resolution by type, with child scopes. A registration is built lazily on the
/// first `resolve` and cached by its lifetime: with the registration, or with the resolving scope.
@MainActor
public final class DependencyContainer {
    private struct Registration {
        let lifetime: DependencyLifetime
        let make: @MainActor (DependencyContainer) -> Any
        var instance: Any?
    }

    private let parent: DependencyContainer?
    private var registrations: [ObjectIdentifier: Registration] = [:]

    /// Scoped instances built through this container, keyed by the same type as the registration.
    private var scopedInstances: [ObjectIdentifier: Any] = [:]

    public init() {
        parent = nil
    }

    private init(parent: DependencyContainer) {
        self.parent = parent
    }

    /// A scope that answers from its own registrations first and falls back to this one.
    public func makeChild() -> DependencyContainer {
        DependencyContainer(parent: self)
    }

    /// Last wins: registering a key again replaces the factory and drops this container's cached
    /// instance for it, singleton or scoped; caches other children already hold are untouched.
    public func register<T>(_ type: T.Type,
                            lifetime: DependencyLifetime = .singleton,
                            factory: @escaping @MainActor (DependencyContainer) -> T) {
        registrations[ObjectIdentifier(T.self)] = Registration(lifetime: lifetime, make: { factory($0) })
        scopedInstances[ObjectIdentifier(T.self)] = nil
    }

    /// The factory is handed the container being resolved through, so a parent's registration
    /// still picks up a child's overrides.
    public func resolve<T>(_ type: T.Type) -> T {
        guard let instance = instance(for: ObjectIdentifier(T.self), through: self) as? T else {
            preconditionFailure("No registration for \(T.self)")
        }
        return instance
    }

    /// Instantiates every registration in this container and its parents; for tests.
    public func resolveAll() {
        var container: DependencyContainer? = self
        while let current = container {
            for key in Array(current.registrations.keys) {
                _ = current.instance(for: key, through: self)
            }
            container = current.parent
        }
    }

    private func instance(for key: ObjectIdentifier, through scope: DependencyContainer) -> Any? {
        guard var registration = registrations[key] else {
            return parent?.instance(for: key, through: scope)
        }
        switch registration.lifetime {
        case .singleton:
            if let instance = registration.instance {
                return instance
            }
            let instance = registration.make(scope)
            registration.instance = instance
            registrations[key] = registration
            return instance
        case .scoped:
            if let instance = scope.scopedInstances[key] {
                return instance
            }
            let instance = registration.make(scope)
            scope.scopedInstances[key] = instance
            return instance
        }
    }
}
