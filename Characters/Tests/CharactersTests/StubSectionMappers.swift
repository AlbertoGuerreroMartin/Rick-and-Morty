//
//  StubSectionMappers.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Combine
import Core
@testable import Characters

/// Publishes the render model a test hands it; `DataModel` is the render model itself.
@MainActor
final class StubSectionMapper<ViewModel, RenderModel>: SectionMapperContract {
    let viewModel: ViewModel
    let renderModels: CurrentValueSubject<RenderModel, Never>

    init(viewModel: ViewModel, renderModel: RenderModel) {
        self.viewModel = viewModel
        renderModels = CurrentValueSubject(renderModel)
    }

    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<RenderModel, Never> {
        renderModels.eraseToAnyPublisher()
    }

    func mapToRenderModel(_ data: RenderModel) -> RenderModel {
        data
    }
}

typealias StubCharactersListSectionMapper = StubSectionMapper<any CharactersListSectionViewModelContract, CharactersListRenderModel>

extension StubSectionMapper: CharactersListSectionMapperContract
    where ViewModel == any CharactersListSectionViewModelContract, RenderModel == CharactersListRenderModel {}

typealias StubCharactersGridSectionMapper = StubSectionMapper<any CharactersGridSectionViewModelContract, CharactersGridRenderModel>

extension StubSectionMapper: CharactersGridSectionMapperContract
    where ViewModel == any CharactersGridSectionViewModelContract, RenderModel == CharactersGridRenderModel {}

typealias StubCharactersFilterBarSectionMapper = StubSectionMapper<any CharactersFilterBarSectionViewModelContract, CharactersFilterBarRenderModel>

extension StubSectionMapper: CharactersFilterBarSectionMapperContract
    where ViewModel == any CharactersFilterBarSectionViewModelContract, RenderModel == CharactersFilterBarRenderModel {}

typealias StubCharacterDetailHeaderSectionMapper = StubSectionMapper<
    any CharacterDetailHeaderSectionViewModelContract,
    CharacterDetailHeaderRenderState
>

extension StubSectionMapper: CharacterDetailHeaderSectionMapperContract
    where ViewModel == any CharacterDetailHeaderSectionViewModelContract, RenderModel == CharacterDetailHeaderRenderState {}

typealias StubCharacterDetailInfoSectionMapper = StubSectionMapper<any CharacterDetailInfoSectionViewModelContract, CharacterDetailInfoRenderModel>

extension StubSectionMapper: CharacterDetailInfoSectionMapperContract
    where ViewModel == any CharacterDetailInfoSectionViewModelContract, RenderModel == CharacterDetailInfoRenderModel {}

typealias StubCharacterDetailEpisodesSectionMapper = StubSectionMapper<
    any CharacterDetailEpisodesSectionViewModelContract,
    CharacterDetailEpisodesRenderModel
>

extension StubSectionMapper: CharacterDetailEpisodesSectionMapperContract
    where ViewModel == any CharacterDetailEpisodesSectionViewModelContract, RenderModel == CharacterDetailEpisodesRenderModel {}
