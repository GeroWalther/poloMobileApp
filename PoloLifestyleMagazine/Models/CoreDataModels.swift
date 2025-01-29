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
        Article(
            id: id ?? "",
            title: title ?? "",
            description: desc ?? "",
            titleImage: titleImage ?? "",
            images: images as? [String],
            createdAt: createdAt
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
        cdArticle.images = images as NSArray?
        cdArticle.createdAt = createdAt
        cdArticle.lastFetchedAt = Date()
        return cdArticle
    }
}