//
//  CharacterDetailViewModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Foundation

@MainActor
final class CharacterDetailViewModel: CharacterDetailHeaderSectionViewModelContract,
                                      CharacterDetailInfoSectionViewModelContract,
                                      CharacterDetailEpisodesSectionViewModelContract {
    var loadingPublisher: AnyPublisher<Bool, Never> {
        $loadingPublished.eraseToAnyPublisher()
    }

    var detailPublisher: AnyPublisher<CharacterDetailModel?, Never> {
        $detailPublished.eraseToAnyPublisher()
    }

    var loadFailedPublisher: AnyPublisher<Bool, Never> {
        $loadFailedPublished.eraseToAnyPublisher()
    }

    let characterDetailUseCase: CharacterDetailUseCaseContract

    /// The character this screen is about, fixed for its whole lifetime.
    ///
    /// It is `let` because the navigation value is the screen's identity: a
    /// pushed detail is *this* character, and a view model whose id could change
    /// would mean a screen that could silently become a different one under a
    /// user who is already reading it.
    let id: String

    init(id: String, characterDetailUseCase: CharacterDetailUseCaseContract) {
        self.id = id
        self.characterDetailUseCase = characterDetailUseCase
    }

    @Published var loadingPublished = false
    /// The character. `nil` means no load has ever landed, which is not the same
    /// as a failure — one draws a spinner and the other an error — and the
    /// header mapper is where that distinction is spent.
    @Published var detailPublished: CharacterDetailModel?
    /// Whether the last (re)load failed.
    @Published var loadFailedPublished = false

    private var hasLoaded = false
    private var isFetching = false

    /// Bumped at the start of every reload; a fetch publishes only while its own
    /// generation is still the current one.
    ///
    /// Cancelling the previous reload task is not enough on its own. A request
    /// that has already left the device cannot be un-sent, and nothing about
    /// `Task.cancel()` guarantees the work stops at a convenient point — least
    /// of all here, where one load is two requests to two different servers. The
    /// counter is what makes a late answer harmless rather than a screen that
    /// flickers back to a character nobody is waiting for.
    private var generation = 0

    /// The in-flight (re)load. Internal, not private, only so tests can await
    /// it: a reload is started from synchronous UI callbacks, so there is
    /// otherwise nothing for a test to wait on but a sleep.
    private(set) var reloadTask: Task<Void, Never>?

    func loadData() async {
        // `.task` is bound to the view's appear/disappear lifetime, so it fires
        // again on every return — after a sheet is dismissed, or when the screen
        // is restored. Only the first one does any work: the character is not
        // going to have changed while the user was looking at it.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        defer { isFetching = false }

        await startReload().value
    }

    /// Re-asks for the character — the Retry button of the failed header.
    /// Unconditional, unlike a load: retrying is the entire point.
    func retryLoad() {
        startReload()
    }

    /// Throws away what is on screen and loads the character again.
    ///
    /// The screen calls this when a cache has been cleared behind its back —
    /// see `CacheClearedNotification`. A cleared cache is invisible on its own,
    /// so the reload is what makes it observable: the next requests have to
    /// leave the device, and the API logger shows them doing so.
    func reloadFromScratch() async {
        reloadTask?.cancel()

        hasLoaded = false
        detailPublished = nil
        await startReload().value
    }

    /// Every load — the first one, a retry, a cache clear — goes through here
    /// and is handled identically: the sections hide behind the spinner, the
    /// character is fetched, and the answer replaces what was there.
    @discardableResult
    private func startReload() -> Task<Void, Never> {
        // A superseded reload's answer is worthless, so cancelling it is the
        // right trade even against the rate limit: whatever it had already
        // cached is still on disk for the newer load to pick up.
        reloadTask?.cancel()
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await reload()
        }
        reloadTask = task
        return task
    }

    private func reload() async {
        generation += 1
        let reloadGeneration = generation

        loadingPublished = true

        do {
            let detail = try await characterDetailUseCase.fetchCharacterDetail(id: id)
            guard reloadGeneration == generation else { return }
            detailPublished = detail
            loadFailedPublished = false
            hasLoaded = true
            loadingPublished = false
        } catch {
            // A cancelled reload owns nothing: the newer one is already driving
            // the state, and clearing the character here would blank its result.
            guard reloadGeneration == generation,
                  !Task.isCancelled,
                  !(error is CancellationError) else { return }
            // `nil` rather than a half-built placeholder: there is no partial
            // character to show, and the failure flag is what the header reads.
            // It also means a Retry starts from the same state the first load
            // did, with no stale name left behind the error.
            detailPublished = nil
            loadFailedPublished = true
            loadingPublished = false
        }
    }
}
