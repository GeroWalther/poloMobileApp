import SwiftUI

struct ArticlesListView: View {
    @EnvironmentObject private var viewModel: MagazineViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)),
                        Color(UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0))
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.gray)
                            Text("Loading Articles...")
                                .foregroundColor(.gray)
                                .font(.headline)
                        }
                    } else if let error = viewModel.error {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                            Text("Failed to load articles")
                                .font(.headline)
                            Text(error.localizedDescription)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task {
                                    await viewModel.fetchArticles()
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.gray)
                        }
                        .foregroundColor(.gray)
                    } else if viewModel.articles.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "newspaper")
                                .font(.system(size: 50))
                            Text("No articles available")
                                .font(.headline)
                        }
                        .foregroundColor(.gray)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(viewModel.articles) { article in
                                    NavigationLink(destination: ArticleDetailView(article: article)) {
                                        ArticleRowView(article: article)
                                    }
                                }
                            }
                            .padding()
                        }
                        .refreshable {
                            await viewModel.fetchArticles(forceRefresh: true)
                        }
                    }
                }
            }
            .navigationTitle("Articles")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.fetchArticles()
                await viewModel.fetchArticlesDirectly()
            }
        }
    }
}

struct ArticleRowView: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: article.titleImage)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        ProgressView()
                            .tint(.gray)
                    )
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(article.publishDate, style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .background(Color.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 