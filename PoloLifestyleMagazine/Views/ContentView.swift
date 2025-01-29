import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            MagazinesView()
                .tabItem {
                    Label("Magazines", systemImage: "magazine")
                }
            
            ArticlesListView()
                .tabItem {
                    Label("Articles", systemImage: "newspaper")
                }
        }
    }
} 