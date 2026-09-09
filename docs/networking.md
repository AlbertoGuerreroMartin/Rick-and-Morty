# Networking

The `Networking` package is a small `URLSession` GraphQL client with no third-party runtime dependencies (SwiftLint is a build-tool plugin only), plus the query and document builders and the API log. It has no local dependencies.

## Endpoints

- `GraphQLClient.rickAndMorty(logger:)` targets `https://rickandmortyapi.com/graphql`, the documented public API.
- `GraphQLClient.justWatch(logger:)` targets `https://apis.justwatch.com/graphql`, an unofficial, undocumented endpoint with introspection disabled. It resolves HBO Max episode links (see [Characters](features/characters.md) and [Episodes](features/episodes.md)). Callers must degrade when it fails rather than surface an error.
- Both are the same client type sharing the same logger, so JustWatch calls appear in the request inspector.

## The client

- Every request is a `POST` to one URL with a JSON body of `query` and `variables`. The document and the variables travel separately so the server can validate and cache the document.
- `execute(_:)` returns `Query.Response`. Failures are `GraphQLClientError`: `transport`, `httpStatus`, `decoding`, `server` (a `200` carrying an `errors` array) or `emptyPayload`.
- `URLCache` is switched off: the default session has no cache and every request ignores local and remote caches. `Storage` is the only cache for API data, so no second invisible copy exists under a policy the repository cannot see.
- The session is injectable, which is how tests run the client through a stubbed `URLProtocol`.

## Describing a query

- A `GraphQLQuery` conformer *is* its variables object: its stored properties are encoded straight into `"variables"`. It names the root field through `objectRequested` and the entity through `ResponseEntity`, whose `@Document` selection set is pasted into the operation and is also the decoded payload.
- `Response` defaults to `GraphQLRootPayload<ResponseEntity>`, which aliases the root field to `result` so every response decodes the same way.
- `GraphQLPaginatedQuery` pins `Response` to a page (`info` + `results`) and derives the document automatically: `page` becomes its own argument and every other stored property nests inside `filter`. A conformer declares only its entity, its root field and its properties.
- `GraphQLOperation.document` assembles the operation text one field per line, so the console log needs no reformatting.
- A non-paginated query (the character detail) still gets its document derived: every stored property becomes a root-field argument. Only the JustWatch show lookup writes its document by hand, because it needs per-field arguments and an inline fragment.

## Pagination

- `GraphQLPageResponse` carries `GraphQLPageInfo` (`count`, `pages`, `next`) and `results`. `info.next` is the server's word on whether there is more, and every feature uses it rather than counting.

## Cache identity

- `GraphQLQuery.cacheIdentifier` is the root field, a SHA-256 of the document, and the sorted-key variables JSON. It is valid for every query, paginated or not.
- Folding the document into the key means an entity gaining a field addresses new cache entries automatically. Old entries stop being read and age out; no manual cache-version bump ever.
- Variables are part of the key, so filtered pages cache themselves per filter and per page for free. An empty filter must build exactly the same query as no filter, so unfiltered entries keep their key across releases. A test guards that identity.

## API logging

- The client takes an `APILogSinkContract` and emits two events per call sharing an `id`: `.request` just before the send and `.response` the moment bytes come back, before any status check or decoding. The log shows what crossed the wire, not what the client made of it.
- `APIRequestRecord` and `APIResponseRecord` are plain values (method, URL, headers, body `Data`, timestamp, outcome, duration) so anything outside the package can render them. `APILogKind` (`.api` or `.image`) lets image downloads reuse the same records.
- `ConsoleAPILogger` prints through `APILogFormatter`, a pure function the tests assert line by line. The GraphQL document is unpacked from its escaped JSON string and printed verbatim. `NoOpAPILogger` is the default.
- `APILogStore` is itself a sink: it keeps the last 500 events in memory, fans each out to registered sinks, and hands out `AsyncStream`s of live events. It is a class under a `Mutex`, not an actor, so the client never awaits a log call and a response can never be recorded before its request.
- Wiring lives in `AppContainer`: one store for the app's lifetime, with the console sink attached only under `#if DEBUG`.
