# Rick and Morty

A SwiftUI iOS app that browses the characters, episodes and locations of the *Rick and Morty* series through the public GraphQL API at https://rickandmortyapi.com.

<table>
  <tr>
    <td><img width="585" height="1266" alt="IMG_9746" src="https://github.com/user-attachments/assets/9d08fa95-f588-456f-b9d8-960ec0232ca8" /></td>
    <td><img width="585" height="1266" alt="IMG_9747" src="https://github.com/user-attachments/assets/e1de46d2-4423-4360-8cf5-bb94b6d3c477" /></td>
    <td><img width="585" height="1266" alt="IMG_9748" src="https://github.com/user-attachments/assets/e91f893c-6f43-4de9-90ac-7b72ca1097ba" /></td>
  </tr>
</table>



## Platform decisions

- **Minimum supported version: iOS 18.6.** Loses very few devices and unlocks the APIs the app is built on: the SwiftUI navigation and `@Observable` APIs, the `Tab` builder, and `Mutex` from the Synchronization module.
- **SwiftUI, MVVM, Swift 6 strict concurrency.** The app is structured around an MVVM architecture, with concrete separate layers, following the SOLID principles. SwiftUI is the UI framework used, as it is the platform standard.
- **Local Swift packages.** All the app's code has been placed into Swift packages, with a thin app target that is the only place that knows every feature that exists. This allows for optimal modularization and really fast compile times due to incremental builds.
- **DI system.** The app has a simple DI system implemented. Each feature module declares a `Dependencies` protocol the app's container conforms to, for global dependencies, and one assembly that registers its internal dependencies into the app's root `DependencyContainer` at launch; each screen resolves from a child scope of it.
- **Cache everything.** The API rate-limits are extremely restrictive, so every query response is cached on disk with a lifetime, and stale data is served when a fetch fails.
- **Full accessibility support.** The app is fully compatible with Voice Over and Dynamic Type basic sizes.
- **Localization support.** The app is fully localized for English and Spanish, using string catalogs.

## Module map

```
RickMorty (app)  ──►  Characters ─┐
                 ──►  Episodes   ─┼──►  Core, Networking, Storage, DesignSystem
                 ──►  Locations  ─┘
                 ──►  DevTools (DEBUG only)  ──►  Networking, Storage, DesignSystem

DesignSystem  ──►  Networking, Storage
Core, Networking, Storage have no local dependencies.
```

| Package | Role |
|---|---|
| `Core` | The architecture core sources (`Owned`, `DependencyContainer`, section contracts) and the `@Document` macro that derives GraphQL documents from entity types. |
| `Networking` | A `URLSession` GraphQL client, and an API logger. |
| `Storage` | The disk store and `Codable` cache with lifetimes, plus the cache log. |
| `DesignSystem` | Image loading (`CachedAsyncImage`) with memory and disk caches and downsampling. |
| `Characters` | Characters feature: contains a landing screen with a characters paginated list and grid with search and filters, and a character detail screen. |
| `Episodes` | Episodes feature: lists the whole episodes catalogue grouped by season, with local search and HBO Max links. |
| `Locations` | Locations feature: stepped carousel with an item per each location, with a detail card and a residents list. |
| `DevTools` | Shake-to-open developer tool: cache clearing and a requests inspector. |

## Documentation

- [Architecture](docs/architecture.md) — layering inside a feature, screen ownership and the section pattern, dependency injection, navigation, concurrency rules.
- [Networking](docs/networking.md) — the GraphQL client, how a query is described and built, pagination, cache identity, API logging.
- [Storage](docs/storage.md) — the disk and cache layers, lifetimes, the repository cache policy, sweeps and clearing.
- [Design system](docs/design-system.md) — the image pipeline and its two caches.
- [Developer tools](docs/dev-tools.md) — the shake gesture, cache clearing, the request inspector, and the console loggers.
- Features
  - [Characters](docs/features/characters.md)
  - [Episodes](docs/features/episodes.md)
  - [Locations](docs/features/locations.md)
- [Development](docs/development.md) — building, running the tests per package, SwiftLint, localization, and simulator gotchas.

## Future improvements
Listed below are the most important topics that were excluded due to time constraints, and could serve as future improvements:
- **Prefetching pages ahead of scroll**: to smooth the user experience, a good improvemnt would be to load the next page on a paginated list before it reaches the bottom, so the next page loading indicator is almost never displayed.
- **Filter locations**: the current locations carrousel doesn't support search or filtering, which makes it hard to find a concrete location.
- **Variants list**: using GraphQL's powerful search queries, build a list of variants of the same character from other universes, listed in the character detail screen.
- **Real usage of DesignSystem package**: now it only contains the image loading and cache layer, but it was meant to serve as a UI kit for the whole app, holding its common, reusable UI components. An extraction of these UI components to this package is pending.
- **Improve Dynamic Type larger sizes support**: the app behaves properly with the basic sizes variations of Dynamic Type, but with the larger ones struggles to render a correct UI. This could be improved adjusting the design of the screens.
- **Add snapshot and end-to-end UI tests**: the package view tests render every screen state on a hosted window and assert the logic wired through it, but there are no snapshot tests, and the app's XCUITest bundle is still the Xcode template.
- **Configure CI**: add GitHub actions to run tests before merging PR, use fastlane to publish signed versions to TestFlight, etc. This topic hasn't been considered since this app is not currently intended to reach the AppStore, but adding CI would be a significant improvement.
