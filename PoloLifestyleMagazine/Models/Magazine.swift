import Foundation

struct Magazine: Identifiable, Codable {
    let id: Int
    let title: String
    let description: String
    var pdf: String
    let createdAt: String
    
    // Computed property to convert createdAt string to Date
    var publishDate: Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: createdAt) ?? Date()
    }
    
    // Add coding keys to match the exact JSON structure
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case pdf
        case createdAt = "created_at"
    }
} 
