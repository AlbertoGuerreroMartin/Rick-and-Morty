# Development

## Building

- Open `RickMorty.xcworkspace`. The app scheme is `RickMorty`; each package has a shared scheme of its own.
- SwiftLint runs on every build as a SwiftPM build tool plugin (see below), so from the command line `xcodebuild` needs `-skipPackagePluginValidation -skipMacroValidation`. Xcode asks once to trust the plugin and the macro.

```bash
xcodebuild -workspace RickMorty.xcworkspace -scheme RickMorty -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -skipMacroValidation build
```

## Tests
- A test plan on the RickMorty target includes the test targets of the packages. The UI tests are listed but disabled, since they increase test run times significantly and aren't currently being used. The Core test target doesn't appear because Core tests only run on macOS, not iOS, and the DevTools test target is not included either.
- Package test suites run through the workspace scheme of that package. A package needs a shared scheme under `<Package>/.swiftpm/xcode/xcshareddata/xcschemes/` for its test action to exist at all; every package has one.

```bash
xcodebuild -workspace RickMorty.xcworkspace -scheme Characters -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -skipPackagePluginValidation -skipMacroValidation test
```

- Never `swift build` or `swift test` at the root. The packages are iOS-only and fail on the host with misleading availability errors.
- `Core` is the exception. Its tests drive the `@Document` macro through swift-syntax, and a macro plugin is a host executable, so `CoreTests` runs on macOS: `swift test` inside `Core`, or the `Core` scheme with the *My Mac* destination. It is deliberately left out of the app's test plan because the plugin object cannot be linked into an iOS Simulator bundle.
- Every test that touches disk gets a fresh UUID directory, so suites are hermetic and run in parallel. Network tests go through a stubbed `URLProtocol`. A suite is `.serialized` only where the stub is configured through a single static value (the client logging suite in Networking, `CachedAsyncImage` in DesignSystem); the `ImageLoader` suites key their stub per URL behind a `Mutex` and run in parallel.
- View tests host each view in a `UIHostingController` on a sized window and force a layout pass, driving sections through the real publisher, mapper and `.onReceive` pipeline. A SwiftUI `body` is lazy, so a crash in one survives any test that only builds the value.
- Time-dependent behaviour (cache expiry, the search debounce) is injected so tests use a fake clock or a zero delay rather than sleeping.

## SwiftLint

- `SwiftLintBuildToolPlugin` from SwiftLintPlugins, pinned to an exact version in all eight `Package.swift` files and in the app project so the nine independent resolutions agree.
- All rules live in the root `.swiftlint.yml`. Each package directory and `RickMorty/` has a stub `.swiftlint.yml` containing only `parent_config: ../.swiftlint.yml`, because the plugin looks for a config inside the package and never walks above it.
- Overriding `identifier_name.excluded` replaces SwiftLint's default list, which is why `id` is re-added explicitly. Entity properties such as `air_date` mirror the API's field names because the property name doubles as the GraphQL selection and coding key.

## Localization

- One `Localizable.xcstrings` per feature package, under its `Resources` folder, with `defaultLocalization: "en"`. The app target has its own catalog for the tab titles only.
- Keys are the English text. Package views use `Text(_, bundle: .module)` and anything that becomes a `String` uses `String(localized:bundle:)`. Counts in the Episodes and Locations catalogs are catalog plurals with a `zero` variation.
- Only text a user or VoiceOver reads is localized. GraphQL documents, cache keys, error descriptions and API values (species, type, the literal `"unknown"`) stay verbatim. `DevTools` is excluded on purpose.
- Status and gender enums get a presentation-side `displayName` extension instead of `rawValue.capitalized`: character status and gender in Characters, resident status in Locations.

## Simulator gotchas

- The developer tools open on a shake: **Device ▸ Shake** (⌃⌘Z). The shake cannot be automated from a script; to verify the sheet without a hand on the keyboard, temporarily post `Notification.Name.devToolsDeviceDidShake` from `RickMortyApp.init` and remove the hook afterwards.
- Debug-level `os.Logger` entries are not persisted, so `log show` returns nothing. Stream them before generating traffic:

```bash
xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "es.aguerrero.RickMorty"'
```

## Conventions

- Comments are one line and state facts. Rationale lives in these documents, not in the source.
- Each UI section owns its contract and mapper files even when rules are duplicated with a sibling section. See [Architecture](architecture.md).
- New cross-feature navigation is one more method on `RickMortyExternalNavigator`, never an import between feature packages.

## AI usage

To facilitate the development process, and in line with current development technology stacks, AI support has been used to develop this project, concretely working with Anthropic's AI models such as Fable 5.1 and Opus 5.