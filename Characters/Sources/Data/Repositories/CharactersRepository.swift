//
//  CharactersRepository.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Foundation
import Storage

protocol CharactersRepositoryContract: Sendable {
    /// One page of the list *for a filter*. The filter is part of the request
    /// rather than state on the repository so that two screens — or two reloads
    /// racing each other — can never read each other's constraints.
    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage

    /// One character, with everything the detail screen shows.
    ///
    /// It takes an id rather than a `CharacterModel` because that is all the
    /// navigation carries: the detail is pushed with an id and fetches its own
    /// answer, so a row that was scrolled past — or a list that was reloaded
    /// underneath it — cannot leave the screen showing a character it no longer
    /// has.
    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel

    /// Where to watch each episode on HBO Max, for every episode that is on it.
    ///
    /// Separate from `fetchCharacterDetail(id:)` rather than folded into it: the
    /// two come from different services and can be asked for at the same time,
    /// and only the caller knows that a missing link is survivable while a
    /// missing character is not. Joining them is `CharacterDetailUseCase`'s job.
    func fetchHBOMaxLinks() async throws -> HBOMaxLinks
}

/// Decides, per request, whether the answer comes from disk or from the network.
///
/// The reason this coordination exists at all is the API's rate limit: rickandmortyapi
/// answers **429** once a client has made too many requests in a short window,
/// and a list screen that refetches on every appearance walks into that quickly
/// — during development most of all, where the same screen is opened dozens of
/// times a minute. Cached pages turn all of those into zero requests.
///
/// The order of the four steps below is the whole policy:
///
/// 1. Read the cache, but never let a cache failure fail the request. A cache is
///    an optimisation; if it is broken the app should be slower, not broken.
/// 2. Fresh entry wins outright — no network at all.
/// 3. Otherwise go to the network and write what comes back. The write is also
///    best-effort: a full disk must not turn a successful fetch into an error.
/// 4. If the network fails and a *stale* entry exists, serve it. A throttled or
///    offline fetch still renders yesterday's characters, which is what the user
///    wants and what an empty error screen fails to give them. Cancellation is
///    the one exception — it means the screen went away, not that the fetch
///    failed, and swallowing it would defeat structured concurrency.
///
/// The four steps live in `fetchThroughCache(label:cached:fetch:store:)` and are
/// what all three of the requests below run on — a page, a character, and the
/// JustWatch offers. Those are three servers' worth of failure modes, but the
/// reason for every one of the four steps is unchanged, and two copies of a
/// policy are two policies the moment one of them is edited.
final class CharactersRepository: CharactersRepositoryContract {
    private let remoteDataSource: CharactersRemoteDataSourceContract
    private let hboMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract
    private let localDataSource: CharactersLocalDataSourceContract
    private let mapper: CharacterEntityMapperContract
    private let detailMapper: CharacterDetailEntityMapperContract
    private let linksMapper: HBOMaxLinksMapperContract

    init(remoteDataSource: CharactersRemoteDataSourceContract,
         hboMaxLinksRemoteDataSource: HBOMaxLinksRemoteDataSourceContract,
         localDataSource: CharactersLocalDataSourceContract,
         mapper: CharacterEntityMapperContract,
         detailMapper: CharacterDetailEntityMapperContract,
         linksMapper: HBOMaxLinksMapperContract) {
        self.remoteDataSource = remoteDataSource
        self.hboMaxLinksRemoteDataSource = hboMaxLinksRemoteDataSource
        self.localDataSource = localDataSource
        self.mapper = mapper
        self.detailMapper = detailMapper
        self.linksMapper = linksMapper
    }

    func fetchCharacters(filter: CharactersFilter, page: Int) async throws -> CharactersPage {
        // Building the query here — and only here — is what keeps the cache
        // honest: the key is derived from the query, so a filtered page and an
        // unfiltered one address different entries without a single extra line
        // in the local data source.
        let query = CharactersQuery(filter: filter, page: page)

        let fetched = try await fetchThroughCache(
            label: "characters page \(page)",
            cached: { try await localDataSource.charactersPage(for: query) },
            fetch: { try await remoteDataSource.fetchCharactersPage(query) },
            store: { try await localDataSource.store($0, for: query) }
        )

        return map(fetched)
    }

    /// One character, through the same four steps, then mapped.
    ///
    /// It takes an id because that is all the navigation carries: the detail is
    /// pushed with a route value and fetches its own answer, so the screen can
    /// never be showing a character the list has since scrolled past or reloaded
    /// away.
    ///
    /// **A detail that will not map throws.** That is the one place this differs
    /// from the list, where an unmappable entity is a skipped row: here there is
    /// no rest of the page to keep, so a half-drawn screen would be strictly
    /// worse than an error the user can retry.
    func fetchCharacterDetail(id: String) async throws -> CharacterDetailModel {
        let query = CharacterDetailQuery(id: id)

        let fetched = try await fetchThroughCache(
            label: "character detail \(id)",
            cached: { try await localDataSource.characterDetail(for: query) },
            fetch: { try await remoteDataSource.fetchCharacterDetail(query) },
            store: { try await localDataSource.store($0, for: query) }
        )

        return try detailMapper.map(fetched)
    }

    /// The show's offers, through the same four steps, then mapped.
    ///
    /// One request for the whole show rather than one per episode: JustWatch
    /// answers with every season and every offer in a single ~120 KB response,
    /// and a character can appear in fifty of them — fifty lookups against an
    /// unofficial endpoint to build one column of buttons would be the wrong
    /// trade by two orders of magnitude.
    ///
    /// Mapping happens here, on every read, so the cache stores the server's
    /// shape and the normalisation rules apply to a week-old entry exactly as
    /// they do to a fresh one. It cannot fail — see `HBOMaxLinksMapper` — so the
    /// only thing this method can throw is the fetch itself.
    func fetchHBOMaxLinks() async throws -> HBOMaxLinks {
        let query = JustWatchShowOffersQuery()

        let offers = try await fetchThroughCache(
            label: "HBO Max links",
            cached: { try await localDataSource.showOffers(for: query) },
            fetch: { try await hboMaxLinksRemoteDataSource.fetchShowOffers(query) },
            store: { try await localDataSource.store($0, for: query) }
        )

        return linksMapper.map(offers)
    }

    /// The four-step policy itself, with the three things that differ — which
    /// entry to read, what to fetch, where to write it — handed in.
    ///
    /// Generic over the value rather than over the query: the query is already
    /// captured by all three closures at the call site, which is also the only
    /// place it can be built correctly. `label` appears in nothing but the log
    /// line, and is a parameter so that line still names *which* fetch could not
    /// be cached.
    ///
    /// - See: the type's documentation for what each of the four steps is for.
    private func fetchThroughCache<Value: Sendable>(
        label: String,
        cached: () async throws -> CacheEntry<Value>?,
        fetch: () async throws -> Value,
        store: (Value) async throws -> Void
    ) async throws -> Value {
        // `try?`: an unreadable cache is a miss, not a failure. Step 1.
        let entry = try? await cached()

        // Step 2.
        if let entry, !entry.isExpired {
            return entry.value
        }

        do {
            let fetched = try await fetch()
            do {
                try await store(fetched)
            } catch {
                // Step 3: the fetch succeeded, so the caller still gets its value.
                print("[ERROR] Could not cache \(label): \(error.localizedDescription)")
            }
            return fetched
        } catch let error as CancellationError {
            throw error
        } catch {
            // Step 4.
            guard let entry else { throw error }
            return entry.value
        }
    }

    /// Mapping happens here, on every read, from disk and network alike — which
    /// is why the cache stores entities. A single entity that fails to map is
    /// logged and skipped rather than failing the page: one character missing a
    /// `name` should not blank the whole list.
    private func map(_ page: CharactersPageEntity) -> CharactersPage {
        let characters = page.results.compactMap { entity -> CharacterModel? in
            do {
                return try mapper.map(entity)
            } catch {
                // Log error without stopping the whole parsing process.
                print("[ERROR] \(error.localizedDescription)")
                return nil
            }
        }
        return CharactersPage(characters: characters, nextPage: page.info.next)
    }
}
