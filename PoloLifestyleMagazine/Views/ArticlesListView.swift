import SwiftUI

struct ArticlesListView: View {
    //@EnvironmentObject private var viewModel: MagazineViewModel
    @EnvironmentObject private var viewModel: ArticleViewModel
    
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
                                NavigationLink {
                                    ArticleDetailView(article: article)
                                } label: {
                                    ArticleRowView(article: article)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 20)  // Add vertical padding to the stack
                    }
                    .refreshable {
                        await viewModel.fetchArticles(forceRefresh: true)
                    }
                }
            }
        }
        .onAppear() {
            Task {
                await viewModel.fetchArticles()
            }
//            let testDate = Calendar.current.date(from: DateComponents(year: 2025, month: 2, day: 22, hour: 9, minute: 30))! // Monday, Feb 19, 9 AM
//            Task { await viewModel.fetchArticles(testLastFetchedAt: testDate) }
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
            // Image
            AsyncImage(url: viewModel.fetchImageFromDocumentsDirectory(imageName: article.titleImage)) { image in
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
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 16)      // Add padding around the entire card
    }
} 
