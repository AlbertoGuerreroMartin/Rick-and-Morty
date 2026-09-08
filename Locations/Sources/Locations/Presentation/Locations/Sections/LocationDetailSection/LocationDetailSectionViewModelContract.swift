//
//  LocationDetailSectionViewModelContract.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine

/// What the card under the carousel needs: loaded locations and which is focused. Deliberately
/// narrower than the carousel's contract — no spinner or failure state, which the carousel owns.
@MainActor
protocol LocationDetailSectionViewModelContract {
    var locationsPublisher: AnyPublisher<[LocationModel]?, Never> { get }
    var selectedLocationIdPublisher: AnyPublisher<String?, Never> { get }
}
