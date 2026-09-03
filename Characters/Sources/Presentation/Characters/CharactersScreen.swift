import SwiftUI
import Networking

struct CharactersScreen<Content: View>: View {
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
    }
}

#Preview {
    
}
