import CoreData
import Foundation

extension CDMagazine {
    convenience init(from magazine: Magazine, context: NSManagedObjectContext) {
        self.init(context: context)
        self.id = Int64(magazine.id)
        self.title = magazine.title
        self.desc = magazine.description
        self.pdf = magazine.pdf
        self.createdAt = magazine.createdAt
        self.lastFetchedAt = Date()
    }
} 
