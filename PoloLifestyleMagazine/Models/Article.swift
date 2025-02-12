import Foundation

struct Article: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    var titleImage: String
    let createdAt: String?
    let sections: [Section]?
    
    struct Section: Codable {
        let subheading: String?
        let text: String?
        let images: [String]?
    }
    
    var publishDate: Date {
        guard let createdAt = createdAt else { return Date() }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createdAt) ?? Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case titleImage = "title_image"
        case createdAt = "created_at"
        case sections
    }
} 
