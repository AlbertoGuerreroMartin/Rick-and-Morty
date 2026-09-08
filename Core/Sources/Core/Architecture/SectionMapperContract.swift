//
//  SectionMapperContract.swift
//  Core
//
//  Created by Alberto Guerrero Martin on 03/09/2026.
//

import Combine
import Foundation

// Main-actor isolated: mappers read view model publishers and feed section views, both of
// which live on the main actor.
@MainActor
public protocol SectionMapperContract {
    associatedtype ViewModel
    associatedtype DataModel
    associatedtype RenderModel

    var viewModel: ViewModel { get }

    func dataPublisher(_ viewModel: ViewModel) -> AnyPublisher<DataModel, Never>
    func mapToRenderModel(_ data: DataModel) -> RenderModel
}

public extension SectionMapperContract {
    func renderModelPublisher<T>() -> AnyPublisher<T, Never> {
        dataPublisher(viewModel)
            .map { self.mapToRenderModel($0) }
            .compactMap { $0 as? T }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}
