struct ContentView: View {
    @StateObject private var magazineViewModel = MagazineViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MagazinesView()
                .environmentObject(magazineViewModel)
                .tabItem {
                    Label("Magazines", systemImage: "magazine")
                }
                .tag(0)
            
            NavigationStack {
                ArticlesListView()
                    .environmentObject(magazineViewModel)
            }
            .tabItem {
                Label("Articles", systemImage: "newspaper")
            }
            .tag(1)
        }
        .accentColor(Color(red: 0.6, green: 0.4, blue: 0.0))
        .onChange(of: selectedTab) { newTab in
            print("📱 Tab changed to: \(newTab)")
        }
        .onAppear {
            print("📱 ContentView appeared")
        }
    }
} 