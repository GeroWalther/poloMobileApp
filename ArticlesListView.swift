struct ArticlesListView: View {
    @EnvironmentObject private var viewModel: MagazineViewModel
    
    var body: some View {
        Group {
            if !viewModel.articles.isEmpty {
                // Always show cached content first if available
                ArticlesList(articles: viewModel.articles)
            } else if viewModel.isLoading {
                // Only show loading if we have no cached data
                LoadingView()
            } else {
                // No cached data at all
                VStack(spacing: 20) {
                    Image(systemName: "newspaper")
                        .font(.system(size: 50))
                    Text("No articles available")
                        .font(.headline)
                }
                .foregroundColor(.gray)
            }
        }
        .task {
            // Only fetch if we have no data at all
            if viewModel.articles.isEmpty {
                await viewModel.fetchArticles()
            }
        }
    }
} 