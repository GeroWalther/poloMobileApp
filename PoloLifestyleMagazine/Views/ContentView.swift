import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MagazinesView()
                .tabItem {
                    Label("Magazines", systemImage: "magazine")
                }
                .tag(0)
            
            NavigationStack {
                ArticlesListView()
            }
            .tabItem {
                Label("Articles", systemImage: "newspaper")
            }
            .tag(1)
        }
        .accentColor(Color(red: 0.6, green: 0.4, blue: 0.0))
    }
} 