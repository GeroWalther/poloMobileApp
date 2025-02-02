import Foundation

class ArticleService {
    static let shared = ArticleService()
    private let decoder: JSONDecoder
    
    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }
    
    func fetchArticles() async throws -> [Article] {
        // Replace with your actual API endpoint
        guard let url = URL(string: "YOUR_API_ENDPOINT") else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode([Article].self, from: data)
    }
} 