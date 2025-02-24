//
//  ArticleViewModel.swift
//  PoloLifestyleMagazine
//
//  Created by MacbookM3 on 21/02/25.
//

import Foundation
import CoreData
import OSLog

@MainActor
class ArticleViewModel: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let articleCacheDuration: TimeInterval = 7 * 24 * 60 * 60  // 1 week
    private let supabase = SupabaseService.shared
    private let logger = Logger(subsystem: "com.gw.PoloLifestyle", category: "ArticleViewModel")
    private let context = PersistenceController.shared.container.viewContext
    var fetchTask: Task<Void, Never>?  // Store the ongoing fetch task

    init() {
        loadCachedData()
    }

    private func loadCachedData() {
        Task {
            let currentDate = Date()

            let articleFetch = NSFetchRequest<CDArticle>(entityName: "CDArticle")
            articleFetch.predicate = NSPredicate(format: "lastFetchedAt > %@", currentDate.addingTimeInterval(-articleCacheDuration) as NSDate)

            do {
                let cdArticles = try context.fetch(articleFetch)

                await MainActor.run {
                    self.articles = cdArticles.map { $0.toArticle() }
                }
            } catch {
                logger.error("Failed to load cached data: \(error)")
            }
        }
    }
    
    func fetchArticles(forceRefresh: Bool = false) async {
        let isValid = self.fetchArticlesFromCoreData(forceRefresh: forceRefresh)
        
        let now = Date()
        let calendar = Calendar.current
        
        // Get last fetched date from Core Data
        let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        var lastFetchedAt: Date?
        do {
            let storedArticles = try context.fetch(fetchRequest)
            lastFetchedAt = storedArticles.first?.lastFetchedAt ?? .distantPast
        } catch {
            print("CoreData fetch failed: \(error)")
        }

        
        let mostRecentSaturday9AM: Date = {
            let calendar = Calendar.current
            let now = Date()
            
            // Get today's weekday (1 = Sunday, 7 = Saturday)
            let todayWeekday = calendar.component(.weekday, from: now)
            
            // Calculate how many days to go back to reach last Saturday
            let daysSinceLastSaturday = (todayWeekday == 7) ? 0 : todayWeekday
            
            // Find the last Saturday
            guard let lastSaturday = calendar.date(byAdding: .day, value: -daysSinceLastSaturday, to: now) else {
                return now
            }
            
            // Convert to local time with 9 AM
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: lastSaturday) ?? lastSaturday
        }()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
        formatter.timeZone = TimeZone.current // Set to device's local time zone

        print("📅 mostRecentSaturday9AM (Local):", formatter.string(from: mostRecentSaturday9AM))
        print("📅 lastFetchedAt (Local):", formatter.string(from: lastFetchedAt!))

        if formatter.string(from: lastFetchedAt!) < formatter.string(from: mostRecentSaturday9AM) {
            print("✅ Missed Saturday Fetch: true")
        } else {
            print("❌ Missed Saturday Fetch: false")
        }
        let missedSaturdayFetch = formatter.string(from: lastFetchedAt!) < formatter.string(from: mostRecentSaturday9AM)
        
        if !isInternetAvailable() || isLoading || (isValid && !forceRefresh && !missedSaturdayFetch) {
            return
        }

        isLoading = true
        error = nil

        fetchTask = Task {
            do {
                let response = try await supabase.client
                    .database
                    .from("articles")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()

                let decoder = JSONDecoder()
                let newArticles = try decoder.decode([Article].self, from: response.data)

                let deleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "CDArticle"))
                _ = try? context.execute(deleteRequest)

                for (index, article) in newArticles.enumerated() {
                    var updatedSections: [Article.Section] = []

                    for section in article.sections ?? [] {
                        var localImagePaths: [String] = []
                        for imageUrlString in section.images ?? [] {
                            if let imageUrl = URL(string: imageUrlString) {
                                let imageName = UUID().uuidString + ".jpg"
                                if let localPath = await saveSectionImageLocally(from: imageUrl, withName: imageName) {
                                    localImagePaths.append(localPath)
                                }
                            }
                        }
                        updatedSections.append(Article.Section(subheading: section.subheading, text: section.text, images: localImagePaths))
                    }

                    let cdArticle = article.toCoreData(context: context, updatedSections: updatedSections)
                    cdArticle.lastFetchedAt = Date()
                    
                    if let imageUrl = URL(string: article.titleImage) {
                        await downloadAndSaveImage(from: imageUrl, for: cdArticle, atIndex: index)
                    }
                }
                saveContext()

                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    self.isLoading = false
                    let _ = self.fetchArticlesFromCoreData()
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isLoading = false
                }
                print("Failed to fetch articles: \(error)")
            }
        }
    }
    
// Uncomment this code for testing purpose if you want to test it simply pass testLastFetchedAt as hardcoded and test it
    
//    func fetchArticles(forceRefresh: Bool = false, testLastFetchedAt: Date? = nil) async {
//        let isValid = self.fetchArticlesFromCoreData(forceRefresh: forceRefresh)
//        
//        let now = Date()
//        let calendar = Calendar.current
//
//        // 1️⃣ Set a hardcoded lastFetchedAt for testing
//        var lastFetchedAt: Date? = testLastFetchedAt // Use test value if provided
//        if lastFetchedAt == nil { // Otherwise, use stored value
//            let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
//            do {
//                let storedArticles = try context.fetch(fetchRequest)
//                lastFetchedAt = storedArticles.first?.lastFetchedAt ?? .distantPast
//            } catch {
//                print("CoreData fetch failed: \(error)")
//            }
//        }
//
//        let mostRecentSaturday9AM: Date = {
//            let calendar = Calendar.current
//            let now = Date()
//            
//            // Get today's weekday (1 = Sunday, 7 = Saturday)
//            let todayWeekday = calendar.component(.weekday, from: now)
//            
//            // Calculate how many days to go back to reach last Saturday
//            let daysSinceLastSaturday = (todayWeekday == 7) ? 0 : todayWeekday
//            
//            // Find the last Saturday
//            guard let lastSaturday = calendar.date(byAdding: .day, value: -daysSinceLastSaturday, to: now) else {
//                return now
//            }
//            
//            // Convert to local time with 9 AM
//            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: lastSaturday) ?? lastSaturday
//        }()
//
//        print("🔍 lastFetchedAt: \(lastFetchedAt)")
//        print("📅 mostRecentSaturday9AM: \(mostRecentSaturday9AM)")
//        
//        let formatter = DateFormatter()
//        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZ"
//        formatter.timeZone = TimeZone.current // Set to device's local time zone
//
//        print("📅 mostRecentSaturday9AM (Local):", formatter.string(from: mostRecentSaturday9AM))
//        print("📅 lastFetchedAt (Local):", formatter.string(from: lastFetchedAt!))
//
//        if formatter.string(from: lastFetchedAt!) < formatter.string(from: mostRecentSaturday9AM) {
//            print("✅ Missed Saturday Fetch: true")
//        } else {
//            print("❌ Missed Saturday Fetch: false")
//        }
//
//    let missedSaturdayFetch = formatter.string(from: lastFetchedAt!) < formatter.string(from: mostRecentSaturday9AM)
//
//        print(missedSaturdayFetch)
//        
//        if !isInternetAvailable() || isLoading || (isValid && !forceRefresh && !missedSaturdayFetch) {
//            print("✅ No need to fetch new articles.")
//            return
//        }
//
//        print("⏳ Fetching new articles from server...")
//        isLoading = true
//        error = nil
//
//        fetchTask = Task {
//            do {
//                let response = try await supabase.client
//                    .database
//                    .from("articles")
//                    .select()
//                    .order("created_at", ascending: false)
//                    .execute()
//
//                let decoder = JSONDecoder()
//                let newArticles = try decoder.decode([Article].self, from: response.data)
//
//                let deleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "CDArticle"))
//                _ = try? context.execute(deleteRequest)
//
//                for (index, article) in newArticles.enumerated() {
//                    var updatedSections: [Article.Section] = []
//
//                    for section in article.sections ?? [] {
//                        var localImagePaths: [String] = []
//                        for imageUrlString in section.images ?? [] {
//                            if let imageUrl = URL(string: imageUrlString) {
//                                let imageName = UUID().uuidString + ".jpg"
//                                if let localPath = await saveSectionImageLocally(from: imageUrl, withName: imageName) {
//                                    localImagePaths.append(localPath)
//                                }
//                            }
//                        }
//                        updatedSections.append(Article.Section(subheading: section.subheading, text: section.text, images: localImagePaths))
//                    }
//
//                    let cdArticle = article.toCoreData(context: context, updatedSections: updatedSections)
//                    cdArticle.lastFetchedAt = Date()
//                    
//                    if let imageUrl = URL(string: article.titleImage) {
//                        await downloadAndSaveImage(from: imageUrl, for: cdArticle, atIndex: index)
//                    }
//                }
//                saveContext()
//
//                DispatchQueue.main.asyncAfter(deadline: .now()) {
//                    self.isLoading = false
//                    let _ = self.fetchArticlesFromCoreData()
//                }
//            } catch {
//                DispatchQueue.main.async {
//                    self.error = error
//                    self.isLoading = false
//                }
//                print("❌ Failed to fetch articles: \(error)")
//            }
//        }
//    }


    
    func fetchArticlesFromCoreData(forceRefresh: Bool = false) -> Bool{
        let currentDate = Date()
        let oneWeekAgo = currentDate.addingTimeInterval(-7 * 24 * 60 * 60) // 1 week ago
        let oneMinAgo = currentDate.addingTimeInterval(-60) // ⏳ 1 minute ago // for testing purpose
        print("One week ago date", oneWeekAgo)

        let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        do {
            let storedArticles = try context.fetch(fetchRequest)
            if !storedArticles.isEmpty {
                let lastFetchedAt = storedArticles.first?.lastFetchedAt ?? .distantPast
                print("last fetch date", lastFetchedAt)
                if !forceRefresh, lastFetchedAt > oneWeekAgo { // for testing purpose change oneMinAgo to oneWeekAgo
                    DispatchQueue.main.async {
                        self.logger.debug("Using cached articles")
                        self.articles = storedArticles
                            .map { $0.toArticle() }
                            .sorted { $0.publishDate > $1.publishDate }
                    }
                    return true
                }
                return false
            }
        } catch {
            print("CoreData fetch failed: \(error)")
        }
        return false
    }
    

    
    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                logger.error("Failed to save context: \(error)")
            }
        }
    }

    func saveSectionImageLocally(from url: URL, withName name: String) async -> String? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(name)

        do {
            let (data, _) = try await URLSession.shared.data(from: url) // ✅ Asynchronous download
            try data.write(to: fileURL)
            return fileURL.lastPathComponent // Store only the filename
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    /// Get the document directory path
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    
    func downloadAndSaveImage(from url: URL, for cdArticle: CDArticle, atIndex index: Int) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            if let filename = saveImageToDocumentsDirectory(data: data, imageName: "\(cdArticle.id ?? UUID().uuidString).jpg") {
                DispatchQueue.main.async {
                    cdArticle.titleImage = filename
                    self.saveContext()

                    // ✅ Instead of modifying the struct directly, we replace it in the array
                    if index < self.articles.count {
                        var updatedArticle = self.articles[index]
                        updatedArticle.titleImage = filename
                        self.articles[index] = updatedArticle
                    }
                }
            }
        } catch {
            print("Failed to download image: \(error)")
        }
    }
    
    func saveImageToDocumentsDirectory(data: Data, imageName: String) -> String? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(imageName)

        do {
            try data.write(to: fileURL)
            return imageName  // Return only the filename
        } catch {
            print("Failed to save image: \(error)")
            return nil
        }
    }

    func fetchImageFromDocumentsDirectory(imageName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(imageName)
        return fileURL
    }
}

extension Date {
    func convertToUTC() -> Date {
        let timeZoneOffset = TimeInterval(TimeZone.current.secondsFromGMT(for: self))
        return self.addingTimeInterval(-timeZoneOffset)
    }
}
