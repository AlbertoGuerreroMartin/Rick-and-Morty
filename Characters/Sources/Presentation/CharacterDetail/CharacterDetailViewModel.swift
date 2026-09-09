//
//  CharacterDetailViewModel.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 07/09/2026.
//

import Combine
import Foundation

/// The whole screen's view of the view model: every section contract plus what the screen itself calls.
@MainActor
protocol CharacterDetailViewModelContract: CharacterDetailHeaderSectionViewModelContract,
                                           CharacterDetailInfoSectionViewModelContract,
                                           CharacterDetailEpisodesSectionViewModelContract {
    func loadData() async

    func reloadFromScratch() async
}

@MainActor
final class CharacterDetailViewModel: CharacterDetailViewModelContract {
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

    let id: String

    init(id: String, characterDetailUseCase: CharacterDetailUseCaseContract) {
        self.id = id
        self.characterDetailUseCase = characterDetailUseCase
    }

    @Published var loadingPublished = false
    /// nil means no load has landed yet, distinct from a failure; the header mapper reads that.
    @Published var detailPublished: CharacterDetailModel?
    @Published var loadFailedPublished = false

    private var hasLoaded = false
    private var isFetching = false

    /// Bumped per reload; a fetch only publishes while its generation is still current.
    private var generation = 0

    /// internal, not private, only so tests can await it.
    private(set) var reloadTask: Task<Void, Never>?

    func loadData() async {
        // `.task` re-fires on every appear; only the first call does work.
        guard !hasLoaded, !isFetching else { return }

        isFetching = true
        defer { isFetching = false }

        await startReload().value
    }

    func retryLoad() {
        startReload()
    }

    func reloadFromScratch() async {
        reloadTask?.cancel()

        hasLoaded = false
        detailPublished = nil
        await startReload().value
    }

    @discardableResult
    private func startReload() -> Task<Void, Never> {
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
            guard reloadGeneration == generation,
                  !Task.isCancelled,
                  !(error is CancellationError) else { return }
            detailPublished = nil
            loadFailedPublished = true
            loadingPublished = false
        }
    }
}
