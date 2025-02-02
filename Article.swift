import Foundation

struct Article: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let title: String
    let description: String
    let titleImage: String
    let sections: [Section]?
    
    struct Section: Codable {
        let subheading: String?
        let text: String?
        let images: [String]?
        
        enum CodingKeys: String, CodingKey {
            case subheading
            case text
            case images
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case title
        case description
        case titleImage = "title_image"
        case sections
    }
} 