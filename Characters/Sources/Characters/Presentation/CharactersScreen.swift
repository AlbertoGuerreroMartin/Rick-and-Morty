import SwiftUI
import Networking

struct CharactersScreen<Content: View>: View {
//    @State var characters: [CharacterEntity] = []
//    @State var characterDetail: CharacterDetailEntity?
    let viewModel: CharactersViewModel
    let charactersListSection: Content
    
    var body: some View {
        NavigationStack {
            charactersListSection
                .navigationTitle("Characters")
        }
        .task {
            await viewModel.loadData()
        }
//        VStack {
//            Text(characterDetail?.debugDescription ?? "Loading...")
//                .foregroundStyle(Color.red)
//            List(characters, id: \.id) { character in
//                Text(character.debugDescription)
//            }
//        }
//        .onAppear {
//            Task {
////                let charactersQuery = CharactersQuery(page: 1, name: "Rick")
//                let charactersQuery = CharactersQuery(status: .dead, gender: .female)
//                let charactersData = try await GraphQLClient.rickAndMorty.execute(charactersQuery)
//                self.characters = charactersData.result.results?.compactMap { $0 } ?? []
//                
//                let characterDetailQuery = CharacterDetailQuery(id: "23")
//                let characterDetailData = try await GraphQLClient.rickAndMorty.execute(characterDetailQuery)
//                self.characterDetail = characterDetailData.result
//            }
//        }
    }
}

#Preview {
    
}
