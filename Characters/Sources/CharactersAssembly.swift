//
//  CharactersAssembly.swift
//  Characters
//
//  Created by Alberto Guerrero Martin on 09/09/2026.
//

import Core

/// The feature's composition root: every collaborator of both Characters screens, registered by
/// contract into the app's root container once at launch. Nothing else calls an initializer.
@MainActor
public enum CharactersAssembly {
    public static func register(in root: DependencyContainer,
                                dependencies: any CharactersDependencies,
                                navigator: CharactersNavigator) {
        registerDataLayer(in: root, dependencies: dependencies)
        registerCharacters(in: root, navigator: navigator)
        registerCharacterDetail(in: root)
    }

    /// Shared by the list and the detail: one cache, one repository, one set of mappers.
    private static func registerDataLayer(in root: DependencyContainer,
                                          dependencies: any CharactersDependencies) {
        // App-level objects are read off `dependencies`, not registered: the root is shared by every feature.
        root.register((any CharactersLocalDataSourceContract).self) { _ in
            CharactersLocalDataSource(cacheStore: dependencies.cacheStore)
        }
        root.register((any CharactersRemoteDataSourceContract).self) { _ in
            CharactersRemoteDataSource(client: dependencies.graphQLClient)
        }
        root.register((any HBOMaxLinksRemoteDataSourceContract).self) { _ in
            HBOMaxLinksRemoteDataSource(client: dependencies.justWatchClient)
        }
        root.register((any CharacterEntityMapperContract).self) { _ in CharacterEntityMapper() }
        root.register((any CharacterDetailEntityMapperContract).self) { _ in CharacterDetailEntityMapper() }
        root.register((any HBOMaxLinksMapperContract).self) { _ in HBOMaxLinksMapper() }
        root.register((any CharactersRepositoryContract).self) {
            CharactersRepository(remoteDataSource: $0.resolve((any CharactersRemoteDataSourceContract).self),
                                 hboMaxLinksRemoteDataSource: $0.resolve((any HBOMaxLinksRemoteDataSourceContract).self),
                                 localDataSource: $0.resolve((any CharactersLocalDataSourceContract).self),
                                 mapper: $0.resolve((any CharacterEntityMapperContract).self),
                                 detailMapper: $0.resolve((any CharacterDetailEntityMapperContract).self),
                                 linksMapper: $0.resolve((any HBOMaxLinksMapperContract).self))
        }
        root.register((any CharactersUseCaseContract).self) {
            CharactersUseCase(repository: $0.resolve((any CharactersRepositoryContract).self))
        }
        root.register((any CharacterDetailUseCaseContract).self) {
            CharacterDetailUseCase(repository: $0.resolve((any CharactersRepositoryContract).self))
        }
    }

    private static func registerCharacters(in root: DependencyContainer, navigator: CharactersNavigator) {
        root.register(CharactersNavigator.self) { _ in navigator }
        root.register((any CharactersViewModelContract).self, lifetime: .scoped) {
            CharactersViewModel(charactersUseCase: $0.resolve((any CharactersUseCaseContract).self))
        }
        // Aliases onto the one view model, so every section subscribes to the same publishers.
        root.register((any CharactersListSectionViewModelContract).self, lifetime: .scoped) {
            $0.resolve((any CharactersViewModelContract).self)
        }
        root.register((any CharactersGridSectionViewModelContract).self, lifetime: .scoped) {
            $0.resolve((any CharactersViewModelContract).self)
        }
        root.register((any CharactersFilterBarSectionViewModelContract).self, lifetime: .scoped) {
            $0.resolve((any CharactersViewModelContract).self)
        }
        root.register(CharactersListSectionMapper.self, lifetime: .scoped) {
            CharactersListSectionMapper(viewModel: $0.resolve((any CharactersListSectionViewModelContract).self))
        }
        root.register(CharactersGridSectionMapper.self, lifetime: .scoped) {
            CharactersGridSectionMapper(viewModel: $0.resolve((any CharactersGridSectionViewModelContract).self))
        }
        root.register(CharactersFilterBarSectionMapper.self, lifetime: .scoped) {
            CharactersFilterBarSectionMapper(viewModel: $0.resolve((any CharactersFilterBarSectionViewModelContract).self))
        }
    }

    /// The id comes from `CharacterDetailContext`, which the detail factory registers in the child scope.
    private static func registerCharacterDetail(in root: DependencyContainer) {
        root.register((any CharacterDetailViewModelContract).self, lifetime: .scoped) {
            CharacterDetailViewModel(id: $0.resolve(CharacterDetailContext.self).id,
                                     characterDetailUseCase: $0.resolve((any CharacterDetailUseCaseContract).self))
        }
        // Aliases onto the one view model, so every section subscribes to the same publishers.
        root.register((any CharacterDetailHeaderSectionViewModelContract).self, lifetime: .scoped) {
            $0.resolve((any CharacterDetailViewModelContract).self)
        }
        root.register((any CharacterDetailInfoSectionViewModelContract).self, lifetime: .scoped) {
            $0.resolve((any CharacterDetailViewModelContract).self)
        }
        root.register((any CharacterDetailEpisodesSectionViewModelContract).self, lifetime: .scoped) {
            $0.resolve((any CharacterDetailViewModelContract).self)
        }
        root.register(CharacterDetailHeaderSectionMapper.self, lifetime: .scoped) {
            CharacterDetailHeaderSectionMapper(viewModel: $0.resolve((any CharacterDetailHeaderSectionViewModelContract).self))
        }
        root.register(CharacterDetailInfoSectionMapper.self, lifetime: .scoped) {
            CharacterDetailInfoSectionMapper(viewModel: $0.resolve((any CharacterDetailInfoSectionViewModelContract).self))
        }
        root.register(CharacterDetailEpisodesSectionMapper.self, lifetime: .scoped) {
            CharacterDetailEpisodesSectionMapper(viewModel: $0.resolve((any CharacterDetailEpisodesSectionViewModelContract).self))
        }
    }
}
