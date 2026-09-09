//
//  StubSectionMappers.swift
//  Episodes
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Combine
import Core
@testable import Episodes

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

typealias StubEpisodesListSectionMapper = StubSectionMapper<any EpisodesListSectionViewModelContract, EpisodesListRenderModel>

extension StubSectionMapper: EpisodesListSectionMapperContract
    where ViewModel == any EpisodesListSectionViewModelContract, RenderModel == EpisodesListRenderModel {}
