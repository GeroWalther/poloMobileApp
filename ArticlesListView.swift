struct ArticlesListView: View {
    @EnvironmentObject private var viewModel: MagazineViewModel
    @State private var taskID = UUID()  // Add this to track task lifecycle
    
    var body: some View {
        Group {
            if viewModel.articles.isEmpty && viewModel.isLoading {
                LoadingView()
            } else if !viewModel.articles.isEmpty {
                ZStack {
                    ArticlesList(articles: viewModel.articles)
                    
                    if viewModel.isRefetching {
                        VStack {
                            Spacer()
                            HStack {
                                ProgressView()
                                Text("Updating articles...")
                            }
                            .padding()
                            .background(.white.opacity(0.9))
                            .cornerRadius(10)
                            Spacer().frame(height: 50)
                        }
                    }
                }
            } else {
                VStack {
                    Image(systemName: "newspaper")
                        .font(.system(size: 50))
                    Text("No articles available")
                        .font(.headline)
                }
                .foregroundColor(.gray)
            }
        }
        .task(id: taskID) {  // Change to task(id:)
            print("\n📱 ARTICLES VIEW: Task started with ID: \(taskID)")
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            if !Task.isCancelled {
                print("📱 ARTICLES VIEW: Calling checkCacheAndFetchIfNeeded")
                await viewModel.checkCacheAndFetchIfNeeded()
                print("📱 ARTICLES VIEW: Completed checkCacheAndFetchIfNeeded")
            } else {
                print("❌ ARTICLES VIEW: Task was cancelled")
            }
        }
        .onAppear {
            print("📱 ARTICLES VIEW: Appeared")
            viewModel.setTabVisibility(isVisible: true)
            print("\n📱 ARTICLES VIEW: onAppear")
            print("• Task ID: \(taskID)")
            print("• Articles count: \(viewModel.articles.count)")
            print("• Is loading: \(viewModel.isLoading)")
            print("• Is refetching: \(viewModel.isRefetching)")
        }
        .onDisappear {
            print("📱 ARTICLES VIEW: Disappeared")
            viewModel.setTabVisibility(isVisible: false)
            print("📱 ARTICLES VIEW: onDisappear")
        }
        .refreshable {
            print("📊 ARTICLES: Manual refresh triggered")
            await viewModel.fetchArticles(forceRefresh: true)
        }
        .onChange(of: viewModel.articles) { newArticles in
            print("📊 ARTICLES: Articles updated - count: \(newArticles.count)")
        }
    }
} 
} 