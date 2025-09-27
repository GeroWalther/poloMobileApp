import SwiftUI

struct ArticlesListView: View {
    //@EnvironmentObject private var viewModel: MagazineViewModel
    @EnvironmentObject private var viewModel: ArticleViewModel
    @State private var hasAppeared = false
    
    var body: some View {
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.articles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 50))
                        Text("Articles")
                            .font(.headline)
                    }
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(viewModel.articles) { article in
                                NavigationLink {
                                    ArticleDetailView(article: article)
                                } label: {
                                    ArticleRowView(article: article)
                                        .onAppear {
                                            // Check if we should load more articles
                                            if viewModel.shouldLoadMore(currentItem: article) {
                                                Task {
                                                    await viewModel.loadMoreArticles()
                                                }
                                            }
                                        }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Loading indicator for more articles
                            if viewModel.isLoadingMore {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading more articles...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                            }
                        }
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity, minHeight: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .refreshable {
                        await viewModel.fetchInitialArticles(forceRefresh: true)
                    }
                }
            }
        }
        .onAppear() {
            Task {
                print("🔍 ArticlesListView onAppear - articles count: \(viewModel.articles.count), hasAppeared: \(hasAppeared)")
                
                if !hasAppeared {
                    // First time appearing - force refresh like pull-to-refresh to fix layout
                    print("🔄 First appearance - forcing refresh like pull-to-refresh")
                    await viewModel.fetchInitialArticles(forceRefresh: true)
                    hasAppeared = true
                } else {
                    print("✅ Already appeared before - no refresh needed")
                    // Subsequent appearances (navigation back) - no refresh needed
                }
            }
        }
        .navigationTitle("Articles")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PoloLifestyleHeader()
            }
        }
        .toolbarBackground(
            Color(UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)),
            for: .navigationBar
        )
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

struct ArticleRowView: View {
    let article: Article
    @EnvironmentObject private var viewModel: ArticleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image with lazy loading
            LazyImageView(article: article, height: 200)
                .onAppear {
                    // Download image if needed when it becomes visible
                    Task {
                        await viewModel.downloadImageIfNeeded(for: article)
                    }
                }
            
            // Text content container with proper padding
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(.custom("Times New Roman", size: 18))
                    .fontWeight(.medium)
                    .foregroundColor(.init(white: 0.2))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)  // Limit to 2 lines for consistency
                    .frame(maxWidth: .infinity, alignment: .leading)  // Ensure full width
                
                Text(article.description)
                    .font(.custom("Times New Roman", size: 16))
                    .foregroundColor(.init(white: 0.3))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)  // Ensure full width
                
                Text(article.publishDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.custom("Times New Roman", size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)  // Increased horizontal padding
            .padding(.vertical, 12)    // Added vertical padding
        }
        .frame(maxWidth: .infinity)  // Ensure the card takes full available width
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)      // Add padding around the entire card
    }
}
