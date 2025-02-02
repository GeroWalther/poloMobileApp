import Foundation
import CoreData

@objc(ArticleImagesTransformer)
class ArticleImagesTransformer: NSSecureUnarchiveFromDataTransformer {
    
    static let name = NSValueTransformerName(rawValue: String(describing: ArticleImagesTransformer.self))
    
    override static var allowedTopLevelClasses: [AnyClass] {
        return [NSArray.self, NSString.self]
    }
    
    static func register() {
        let transformer = ArticleImagesTransformer()
        ValueTransformer.setValueTransformer(transformer, forName: name)
    }
}

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "PoloLifestyleMagazine")
        
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - CoreData Conversions
extension CDMagazine {
    func toMagazine() -> Magazine {
        Magazine(
            id: Int(id),
            title: title ?? "",
            description: desc ?? "",
            pdf: pdf ?? "",
            createdAt: createdAt ?? ""
        )
    }
}

extension CDArticle {
    func toArticle() -> Article {
        // Convert stored sections data back to [Section]
        var decodedSections: [Article.Section]?
        if let sectionsData = self.sectionsData {
            let decoder = JSONDecoder()
            decodedSections = try? decoder.decode([Article.Section].self, from: sectionsData)
        }
        
        return Article(
            id: id ?? "",
            title: title ?? "",
            description: desc ?? "",
            titleImage: titleImage ?? "",
            createdAt: createdAt,
            sections: decodedSections
        )
    }
}

// MARK: - Model to CoreData Conversions
extension Magazine {
    func toCoreData(context: NSManagedObjectContext) -> CDMagazine {
        let cdMagazine = CDMagazine(context: context)
        cdMagazine.id = Int64(id)
        cdMagazine.title = title
        cdMagazine.desc = description
        cdMagazine.pdf = pdf
        cdMagazine.createdAt = createdAt
        cdMagazine.lastFetchedAt = Date()
        return cdMagazine
    }
}

extension Article {
    func toCoreData(context: NSManagedObjectContext) -> CDArticle {
        let cdArticle = CDArticle(context: context)
        cdArticle.id = id
        cdArticle.title = title
        cdArticle.desc = description
        cdArticle.titleImage = titleImage
        cdArticle.createdAt = createdAt
        
        // Convert sections to JSON data for storage
        if let sections = sections {
            let encoder = JSONEncoder()
            if let sectionsData = try? encoder.encode(sections) {
                cdArticle.sectionsData = sectionsData
            }
        }
        
        cdArticle.lastFetchedAt = Date()
        return cdArticle
    }
}
