//
//  Owned.swift
//  Core
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine

/// Gives a SwiftUI view ownership of a reference graph without observation.
///
/// A screen needs something to keep its object graph (view model, mappers, ...)
/// alive across body evaluations: SwiftUI views are transient values, so a graph
/// stored in a plain `let` is rebuilt — and the previous one deallocated — every
/// time the parent body runs. `@StateObject` is the only property wrapper that
/// gives per-identity storage plus a lazy autoclosure, but it also *observes*.
///
/// `Owned` bridges that gap. It conforms to `ObservableObject` only so it can
/// live in `@StateObject`. It has no published properties and never fires
/// `objectWillChange`, so the owning view's body is never re-evaluated because
/// of it. Data flow stays where this architecture wants it: view model
/// publishers -> section mapper -> section view `@State` via `.onReceive`, so
/// only the sections re-render when data changes.
@MainActor
public final class Owned<Value>: ObservableObject {
    public let value: Value

    public init(_ make: () -> Value) {
        self.value = make()
    }
}
