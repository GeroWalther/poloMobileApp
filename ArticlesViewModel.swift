import Foundation

@MainActor
class ArticlesViewModel: ObservableObject {
    @Published var articles: [Article] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func loadArticles() async {
        isLoading = true
        do {
            articles = try await ArticleService.shared.fetchArticles()
        } catch {
            self.error = error
        }
        isLoading = false
    }
} 