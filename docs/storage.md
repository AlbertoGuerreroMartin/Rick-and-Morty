# Storage

The `Storage` package is the only cache for API data. It exposes two protocols and one implementation of each, plus the cache log. It has no local dependencies.

## Why there is a cache

- rickandmortyapi answers `429 Too Many Requests` to a client that asks too often. A list that refetched on every appearance would hit that quickly, and fastest of all in development.
- The catalogue is finished fiction. A day-old name is invisible to the user; a refetch on every launch is not.

## Two layers

- `DiskStoreContract` is bytes on disk grouped by namespace. `FileDiskStore` is an actor writing atomically to `<root>/<namespace>/<sha256(identifier)>`. It also lists namespaces and per-file entries (size, modification date) so sweeps and caps can run without knowing the keys.
- `CacheStoreContract` layers `Codable` values with a lifetime on top. `CodableCacheStore` wraps each value in an envelope with `storedAt` and `expiresAt`, keeps a memory layer in front of the disk, and answers `entry(for:as:)` with a `CacheEntry` that says whether it is expired.
- Splitting the two lets a cache policy be tested with no filesystem and the filesystem be tested with no `Codable` type. The image cache sits directly on the disk layer because it has no lifetime.
- A `CacheKey` is a namespace and an identifier. Features use their own namespace (`characters`, `episodes`, `locations`) and `query.cacheIdentifier` as the identifier.

## Where files live

- Under `Library/Caches`, excluded from backups and purgeable by the OS. Every byte is re-derivable from the network, so a purge costs latency and nothing else.

## Lifetimes

| Data | Lifetime | Why |
|---|---|---|
| Character pages, character detail | 24 hours | The screen the user is looking at. |
| Episodes, locations | 7 days | Catalogues that almost never change; expiry costs a multi-page walk for episodes. |
| HBO Max offers (JustWatch) | 7 days | Changes when a licensing deal does; the least deserving request to repeat daily. |

## What the repositories do with it

Every repository runs the same four-step policy through one private generic helper:

1. A fresh entry wins outright.
2. Otherwise fetch, store best-effort, and return.
3. If the fetch fails and a stale entry exists, serve it. A throttled or offline fetch still renders yesterday's data.
4. `CancellationError` is rethrown, never swallowed: it means the screen went away.

- Entities are cached, not domain models. The stored bytes stay a faithful copy of the wire format and the mapper runs on every read, from disk and from network through one code path.
- Each local data source is a handful of two-line methods over the store keyed on `query.cacheIdentifier`. Adding a cached endpoint is one method, not a new key scheme.

## Broken entries and sweeps

- Nothing throws over a broken cache. An entry that no longer decodes is a miss: the file is deleted on read and the value refetched. A schema change can never brick the app.
- `AppContainer.sweepExpiredCache()` runs detached at low priority on launch and calls `removeExpired()`. The sweep only deletes files it can positively read as expired envelopes, because the disk store is shared with the image cache and "cannot parse" also describes every JPEG.

## Clearing

- `removeAll(in:)` drops a namespace on disk and trims the memory layer to match, so a warm copy cannot outlive its file. Features expose it through `*Factory.purgeCache(root:)` so nothing outside the module has to spell the namespace.
- After a clear, `CacheClearedNotification` (`Notification.Name.cacheDidClear`) is posted with the cache names. Screens observe it and reload from scratch. Neither side knows the other exists; both already depend on `Storage`. See [Developer tools](dev-tools.md).

## Cache logging

- `CodableCacheStore` logs every read outcome through a `CacheLogSinkContract`: a hit with the layer that answered and whether it was expired, or a miss. An undecodable envelope is deleted and logged as a miss. An expired hit is a hit; deciding whether stale is acceptable is the repository's job.
- `ConsoleCacheLogger` writes one line per event to unified logging category `Cache`, separate from Networking's `API` category, so the hundreds of avatar reads do not bury the handful of real requests. The identifier is printed verbatim because the on-disk name is a one-way hash.
- `CacheLogStore` mirrors `APILogStore` (500-event history, sinks, live streams). The duplication is deliberate: `Storage` cannot import `Networking` without inverting the dependency.
