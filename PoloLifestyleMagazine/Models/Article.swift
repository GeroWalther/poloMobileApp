import Foundation

struct Article: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let titleImage: String
    let images: [String]?
    let createdAt: String?
    
    var publishDate: Date {
        guard let createdAt = createdAt else { return Date() }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: createdAt) ?? Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case titleImage = "title_image"
        case images
        case createdAt = "created_at"
    }
} 