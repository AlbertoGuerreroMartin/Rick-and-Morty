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
/// An override on `UIWindow`, not a `UIViewControllerRepresentable`: `motionEnded` reaches the
/// window through the responder chain regardless of which screen or sheet is on top.
///
/// - Important: only the `import` is behind `#if DEBUG`; the app links this package in every
///   configuration, so the override itself must stay conditional too or it would swizzle in release.
#if DEBUG
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        // super called first so other motion listeners (shake-to-undo included) still work.
        super.motionEnded(motion, with: event)
        guard motion == .motionShake else { return }
        NotificationCenter.default.post(name: .devToolsDeviceDidShake, object: nil)
    }
}
#endif

public extension View {
    /// Presents ``DevToolsScreen`` when the device is shaken. In the simulator: Device ▸ Shake (⌃⌘Z).
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
                // Toggled, not set: a second shake dismisses the sheet too.
                isPresented.toggle()
            }
            .sheet(isPresented: $isPresented) {
                DevToolsScreen(caches: caches, apiLog: apiLog, cacheLog: cacheLog)
            }
    }
}
