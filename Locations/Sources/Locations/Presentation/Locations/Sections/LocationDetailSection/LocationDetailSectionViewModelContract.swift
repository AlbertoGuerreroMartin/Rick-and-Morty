//
//  LocationDetailSectionViewModelContract.swift
//  Locations
//
//  Created by Alberto Guerrero Martin on 08/09/2026.
//

import Combine

/// What the card under the carousel needs: the locations that were loaded, and
/// which of them is focused.
///
/// Deliberately narrower than the carousel's. This section has no spinner, no
/// failure state and no button — the carousel above it owns all three, and it is
/// the part of the screen the user is looking at while a load runs — so asking
/// for `loadingPublisher` or `loadFailedPublisher` here would be declaring a
/// dependency on something it cannot act on, and the compiler would stop
/// noticing if that ever changed.
///
/// It takes the *list* plus an id rather than the selected location itself. The
/// view model would then hold a second copy of a location that is already in the
/// list, and two copies are two answers the moment a reload replaces one of
/// them; resolving the id here means the card can only ever describe something
/// the carousel is actually showing.
///
/// Main-actor isolated: the conforming view models, the mapper and the section
/// views all live on the main actor, and `@Published` projected values can only
/// be read from the view model's own isolation domain.
@MainActor
protocol LocationDetailSectionViewModelContract {
    var locationsPublisher: AnyPublisher<[LocationModel]?, Never> { get }
    var selectedLocationIdPublisher: AnyPublisher<String?, Never> { get }
}
