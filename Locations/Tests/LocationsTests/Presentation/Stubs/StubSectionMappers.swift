//
//  StubSectionMappers.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Combine
import Core
@testable import Locations

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

typealias StubLocationsCarouselSectionMapper = StubSectionMapper<any LocationsCarouselSectionViewModelContract, LocationsCarouselRenderModel>

extension StubSectionMapper: LocationsCarouselSectionMapperContract
    where ViewModel == any LocationsCarouselSectionViewModelContract, RenderModel == LocationsCarouselRenderModel {}

typealias StubLocationDetailSectionMapper = StubSectionMapper<any LocationDetailSectionViewModelContract, LocationDetailRenderModel>

extension StubSectionMapper: LocationDetailSectionMapperContract
    where ViewModel == any LocationDetailSectionViewModelContract, RenderModel == LocationDetailRenderModel {}
