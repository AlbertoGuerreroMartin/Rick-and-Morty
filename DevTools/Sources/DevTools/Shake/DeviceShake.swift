//
//  DeviceShake.swift
//  DevTools
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Networking
import Storage
import SwiftUI
import UIKit

public extension Notification.Name {
    /// Posted when the device is shaken. See ``SwiftUICore/View/devToolsOnShake(caches:apiLog:cacheLog:)``.
    static let devToolsDeviceDidShake = Notification.Name("DevToolsDeviceDidShake")
}

/// Turns the shake gesture into a notification.
///
/// An override on `UIWindow` because SwiftUI has no motion event of its own:
/// `motionEnded` arrives through the responder chain, and the window is the one
/// responder that exists no matter which screen is on top. A
/// `UIViewControllerRepresentable` would have to be somewhere in the hierarchy
/// and would stop working the moment it was covered by a sheet.
///
/// A notification rather than a callback for the same reason — the shake is
/// caught at the window and has to reach a view that knows nothing about it.
///
/// - Important: an extension on a UIKit class applies process-wide, and the app
///   links this package in every configuration — only the `import` is behind
///   `#if DEBUG`. The override itself is therefore compiled only for debug
///   builds: a release build carries no method swizzle for a screen it cannot
///   open, and the modifier below simply never fires there.
#if DEBUG
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        // Called first, so nothing else that listens for a motion event — the
        // system's own shake-to-undo included — stops working because of this.
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        NotificationCenter.default.post(name: .devToolsDeviceDidShake, object: nil)
    }
}
#endif

public extension View {
    /// Presents ``DevToolsScreen`` when the device is shaken.
    ///
    /// Shake rather than a button or a corner tap: it needs no space in a UI
    /// that ships, it cannot be found by accident, and it works from any screen
    /// including one that has covered everything else with a sheet.
    ///
    /// In the simulator the gesture is **Device ▸ Shake** (⌃⌘Z).
    ///
    /// - Parameters:
    ///   - caches: what the screen offers to clear, supplied by the app's
    ///     container — see `AppContainer.devToolsCaches`.
    ///   - apiLog: the store the GraphQL client and the image loader write to.
    ///   - cacheLog: the store the cache store and the image loader write to.
    func devToolsOnShake(
        caches: [DevToolsCache],
        apiLog: APILogStore,
        cacheLog: CacheLogStore
    ) -> some View {
        modifier(DevToolsShakeModifier(caches: caches, apiLog: apiLog, cacheLog: cacheLog))
    }
}

struct DevToolsShakeModifier: ViewModifier {
    let caches: [DevToolsCache]
    let apiLog: APILogStore
    let cacheLog: CacheLogStore

    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .devToolsDeviceDidShake)) { _ in
                // Toggled rather than set, so a second shake dismisses the sheet
                // — the gesture is the only way in and should be the way out.
                isPresented.toggle()
            }
            .sheet(isPresented: $isPresented) {
                DevToolsScreen(caches: caches, apiLog: apiLog, cacheLog: cacheLog)
            }
    }
}
