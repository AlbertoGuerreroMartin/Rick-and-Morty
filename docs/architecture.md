# Architecture

This document defines the application's architecture, its layers, and the most relevant technical aspects of its implementation.

## Packages

- Each component is a local Swift package with its own tests and a shared scheme. Packages are separate compilation units, so builds stay incremental and boundaries are enforced by `Package.swift` rather than by discipline.
- `Characters`, `Episodes` and `Locations` depend on `Core`, `Networking`, `Storage` and `DesignSystem`, and never on each other, since they are feature packages.
- The app target (`RickMorty`) is the composition root: the only place that imports every feature, and the owner of the root `DependencyContainer` every feature's assembly registers into.

## Architecture layers

All of the feature packages follow the architecture design, which consists of 3 main layers:
```
Data           API queries, DataSources (remote + local), Mappers, Entities, Repository
Domain         Models, UseCases
Presentation   Screen, Factory, ViewModel, Navigator, Route, Sections/
```

All of the components are wrapped into `*Contract` protocols, and are injected via constructor, complying with SOLID rules, and making testing easy with direct fakes injection.


### Data
Contains every source related to the fetching of data and the communication with the APIs. The repositories act as the root point, deciding whether to retrieve the data from cache or API, and mapping the results. This layer defines its own network entity models, which are then mapped to the domain models that will be used on the other layers.

Its internal structure goes as follows:
- **API**: the query objects for the GraphQL requests.
- **Data sources**: the objects responsible for getting the data from cache (`LocalDataSource`) or API (`RemoteDataSource`).
- **Mappers**: convenience components that map entity models to domain models.
- **Models**: the raw entity models definition. They use the @Document macro to automatically generate the GraphQL query document.
- **Repositories**: the root component, orchestrates the retrieval of the data, the storage on the cache, and the mapping of the result entities to domain models.


### Domain
Acts as a bridge between Presentation and Data layers, defining use cases (called by the view models) that orchestrate the call to the repositories, returning ready to render domain models.

Its internal structure goes as follows:
- **Models**: where the domain models are actually defined, as immutable value types that comply with the Swift 6 strict concurrency rules implementing Sendable, so they can safely travel from background use cases to main-actor view models.
- **Use cases**: the actual bridge. Here the needed repositories are called, and their results are combined properly, returning to the presentation layer as domain models.


### Presentation
The biggest layer of the architecture. It's responsible for all the UI rendering, the interaction with the user, and the business logic associated with all of this. The view model is the root component of this layer, handling the call to the domain layer to obtain data, the update of the UI using Combine publishers, the handling of the user actions, and the internal business logic that glues all together.

About the views themselves, they are split into `Sections`, which essentially are subviews that update independently when needed (instead of redrawing the whole view each time), and receive only the piece of data they need through custom section mappers. Data flows one way: view model publishers → mapper → section `@State` via `.onReceive`. Only sections re-render; the screen body never re-evaluates because of data.

Its internal structure goes as follows:
- **\<Screen folder\>:** one folder for each screen, with the following substructure:
    - **\<Sections folder\>:** a folder to contain the implementation of each screen's sections, on a folder per section. Each section folder contains, at least:
        - **\<Section\>Mapper:** the component that gets the information that the section needs from the view model, and maps them into a ready-to-use RenderModel for the section view. All the communication with the view model occurs using combine publishers, so the section is updated each time a change occurs in one of the models it depends on.
        - **\<Section\>View:** the view itself. Receives a `renderModelPublisher` that provides the result of the mapper, and renders the UI based on that `renderModel`.
        - **\<Section\>ViewModelContract:** a protocol that defines the publishers and methods each section requires in the view model. The view model implements all of these contracts.
    - **\<Screen\>Factory:** builds the screen and the sections.
    - **\<Screen\>Screen:** the screen itself, renders the root skeleton of the view, placing the sections. Also builds the navigation stack.
    - **\<Screen\>ViewModel:** the root component. Implements all the contracts of the sections, with a @Published property associated to each publisher. Handles business logic, calling use cases and updating its properties, propagating the changes to the sections.
- **Navigation**: defines the `Navigator` object the screens will use to handle navigation to child views.

## Screen ownership

- SwiftUI views are values, so a view model held in a plain `let` is rebuilt every time the parent body runs. `Owned<Value>` in `Core` solves this: it conforms to `ObservableObject` only so it can live in `@StateObject`, and it never fires `objectWillChange`. The screen owns the scope without observing it.
- Each screen holds `Owned<DependencyContainer>`: one child scope per screen identity, built once, so every section resolves the same view model and the same mapper instance on every parent evaluation.
- `*Factory` is a stateless enum. `build` returns a screen whose `makeScope` closure is `root.makeChild()` — invoked once through `Owned` — and whose `makeSection` closure resolves and composes the sections inside `body`. The factory registers nothing; the only exception is the per-screen route value the CharacterDetailFactory puts in its own child (`CharacterDetailContext`).

## Dependency injection

A simple DI system has been built to manage the dependencies of all of the app's layers. Due to the simplicity of this project I've decided not to include a third-party option, which would increase complexity, build times, etc. The app-to-feature boundary stays compile-time checked: the `*Dependencies` protocols, not the container, are what a feature requires from the app.
- Each feature declares a public `*Dependencies` protocol with exactly what it uses. `CharactersDependencies` and `EpisodesDependencies` need the GraphQL client, the JustWatch client and the cache store; `LocationsDependencies` needs no JustWatch client because a location doesn't have an episode to watch.
- `AppContainer` owns the long-lived infrastructure (clients, cache store, log stores, navigators), conforms to every feature protocol through empty extensions, and holds the root container. A new requirement in a feature is a compile error in the app until the container provides it.
- One public assembly per feature — `CharactersAssembly`, `EpisodesAssembly`, `LocationsAssembly` — with a single `register(in:dependencies:navigator:)`, called once each from `AppContainer.init`. Every dependency is registered there by contract; nothing outside an assembly calls an initializer, except the route value below. The GraphQL clients are read off `dependencies` inside the closures instead of being registered, because one key cannot hold both.
- A view model is registered by its `*ViewModelContract`, never by concrete type. That contract refines every section contract of its screen and adds what the screen itself calls (`loadData()`, `reloadFromScratch()`, etc), so the screen resolves one key. The section aliases resolve that same contract and widen to their own, which keeps every section on the one instance.
- Lifetimes. `.singleton` caches in the container holding the registration: data sources, entity and links mappers, repositories, use cases and navigators are registered in the root, so the whole app shares one of each — Characters registers its data layer once for both of its screens. `.scoped` caches in the container resolved through, so view models, section view-model aliases and section mappers are one per screen scope and a new screen gets a new set.
- A screen resolves from `root.makeChild()`, held by `Owned` for the screen's identity. Two pushes of the character detail are two children, two view models, one repository.
- Values a route carries are registered in the child: `CharacterDetailContext` holds the character id, and the scoped `CharacterDetailViewModel` factory resolves it from the scope it is built in, so the id is never closed over.
- Registering a key again replaces the factory and drops that container's cached instance for it, singleton or scoped. Previews and tests run the real assembly and then override one registration in the root — usually the repository — to cut the network off.
- `purgeCache(root:)` resolves the feature's local data source from the root and empties its namespace; it needs no screen scope.

## Navigation

- One `NavigationStack` per tab, bound to a typed `[Route]` array on an `@Observable`, `@MainActor` navigator. Each feature declares its own route enum, so a link carrying the wrong type is a compile error instead of a silently dead row. The destination switch is exhaustive, and a test can read the path back.
- A route carries an id, never a model. The detail fetches everything anyway, and a model on the path would outlive the row it came from.
- Navigators live on `AppContainer`, not per screen: a tab root's stack lives as long as the app. The assembly registers the instance it is handed rather than creating one.
- Declarative `NavigationLink(value:)` rows and programmatic `showCharacter(id:)` write to the same path. `CharactersNavigator.showCharacter` replaces the path; the Episodes and Locations navigators append, because there the character is a detour and Back must return to where the user was.
- Sheets (filters, developer tools) stay on `.sheet`, never on the path.
- Cross-package pushes go through a protocol the feature declares: `EpisodesExternalDestinations` and `LocationsExternalDestinations` both require `characterDetail(id:)` returning an associated `CharacterDetail: View`, so the screen stays generic and nothing is erased to `AnyView`. `RickMortyExternalNavigator` in the app conforms to both with one `some View` method that calls `CharactersFactory.buildCharacterDetail`, which returns the detail without its own stack so it composes into whichever stack pushes it.

## Concurrency

- View models, mappers and section contracts are `@MainActor`. A main-actor type cannot satisfy a nonisolated protocol requirement, so isolation cascades to the protocols.
- Navigators are `@MainActor` because a path is UI state read during `body`.
- `Sendable` is verified under Swift 6 across the whole object graph. Stores that the network client must never await (`APILogStore`, `CacheLogStore`) are classes under a `Mutex` rather than actors, so event order is preserved.
- Repositories rethrow `CancellationError` instead of treating it as a failure: it means the screen went away.

## The `@Document` macro

- `@Document` in `Core` generates a `document` selection set from a type's stored properties. A property whose type conforms to `GraphQLDocumentConvertible` expands into a nested selection, bounded by a depth.
- Entity property names mirror the API's field names (including `air_date`) because the property name doubles as the GraphQL selection and the coding key.
- Adding a field to an entity changes the document, which changes the cache key. See [Networking](networking.md) and [Storage](storage.md).
