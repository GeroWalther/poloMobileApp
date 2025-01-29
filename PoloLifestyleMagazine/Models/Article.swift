import Foundation

struct Article: Identifiable, Codable {
    let id: String  // Change back to String since the UUID is coming as a string from the API
    let title: String
    let description: String
    let titleImage: String
    let images: [String]?  // Make optional since it might be null
    let createdAt: String?  // Make optional since I don't see it in your SQL results
    
    // Computed property to convert createdAt string to Date
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