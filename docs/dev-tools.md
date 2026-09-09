# Developer tools

The `DevTools` package is a debug-only sheet for clearing caches and inspecting requests. It depends on `Networking`, `Storage` and `DesignSystem`. The app links it in every configuration but imports it only under `#if DEBUG`, which is why the shake override below is conditional too.

<table>
  <tr>
    <td><img width="585" height="1266" alt="IMG_9760" src="https://github.com/user-attachments/assets/d926b8a3-b60f-4751-879d-3a92f08d2678" /></td>
    <td><img width="585" height="1266" alt="IMG_9761" src="https://github.com/user-attachments/assets/77c4e5e8-352b-43ac-a8aa-97e939844788" /></td>
    <td><img width="585" height="1266" alt="IMG_9762" src="https://github.com/user-attachments/assets/0bedebfd-1c5a-49a0-9c07-3ae62b6b0850" /></td>
    <td><img width="585" height="1266" alt="IMG_9763" src="https://github.com/user-attachments/assets/f4fcb3cf-901b-45f8-a996-916952720f0a" /></td>
  </tr>
</table>

## It skips the architecture on purpose

- No `*Contract` protocols, no section mappers, no use cases. The screen is a `List` over an array of closures plus two `@Observable` models. Those layers exist so features can grow without becoming untestable; a tool that never ships does not need them.

## Opening it

- `devToolsOnShake(caches:apiLog:cacheLog:)` wraps the app's `TabView` and presents `DevToolsScreen` in a sheet on a shake.
- The gesture is caught by an override of `UIWindow.motionEnded`, which posts `Notification.Name.devToolsDeviceDidShake`. The window is the one responder that exists whatever screen or sheet is on top, and SwiftUI has no motion event of its own. `super` is called first so shake-to-undo keeps working. A second shake dismisses.
- In the simulator: **Device ▸ Shake** (⌃⌘Z). The override is compiled under `#if DEBUG` too, so a release build carries no swizzle.

## Clearing caches

- `DevToolsCache` is a name and a `@Sendable () async throws -> Void`. `AppContainer.devToolsCaches` lists images, Characters, Episodes and Locations; each feature entry calls its `*Factory.purgeCache(root:)`, so the namespaces stay private to their features. Adding a cache is one line in the container and no change in `DevTools`.
- One button per cache plus "Clear all". "Clear all" runs sequentially, not in a task group, because every cache hits the same disk store; one failure does not stop the rest, and a cache that throws shows its error on its row.
- After a successful clear the model posts `CacheClearedNotification` once per tap. Every screen observes it and calls its view model's `reloadFromScratch()`: the Characters reload keeps the applied filter, the Episodes reload keeps the search text. The tool does not know which screens exist and the screens do not know who cleared what. See [Storage](storage.md).

## Request inspector

- `RequestInspectorModel` subscribes to both `APILogStore` and `CacheLogStore` live streams first, then seeds from their histories, so nothing logged in between is lost. Events are de-duplicated by id and each `start()` begins from an empty list, because `.task` runs again every time the inspector re-appears.
- A `.request` appends a pending row and its `.response` fills that row in place, keeping the request's timestamp. A response whose request has fallen off the 500-event history becomes its own row.
- Rows are newest first, filtered by All / API / Images / Cache and by a search field matching the whole text of each entry, so a character's name in a response body finds the call.
- The detail view shows text verbatim from the packages' own formatters. The console and the inspector cannot disagree about what a request looked like.
- The toolbar "Clear" button empties both log stores, not just the visible list, so the next `start()` seeds from nothing.

## Console loggers

- `ConsoleAPILogger` (category `API`) prints each request and response in full, with the GraphQL document unpacked and the variables as indented JSON.
- `ConsoleCacheLogger` (category `Cache`) prints one line per cache read. The two categories exist so the Xcode console filter can pick one or the other; cache reads happen for every row and avatar and would bury the real requests.
- Both are attached in `AppContainer` only under `#if DEBUG`. Release builds keep the in-memory history and a silent console.
- Debug-level unified-logging entries are not persisted. To capture them from the simulator, stream them before generating traffic (see [Development](development.md)).
