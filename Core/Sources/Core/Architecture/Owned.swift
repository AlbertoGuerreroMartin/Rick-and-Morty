//
//  Owned.swift
//  Core
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine

/// Gives a SwiftUI view ownership of a reference graph without observation. Conforms to
/// `ObservableObject` only to live in `@StateObject`; it never fires `objectWillChange`, so the
/// owning view's body never re-renders because of it — only the section views do, via
/// `.onReceive` on the view model's own publishers.
@MainActor
public final class Owned<Value>: ObservableObject {
    public let value: Value

    public init(_ make: () -> Value) {
        self.value = make()
    }
}
