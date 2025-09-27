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
    @Published private(set) var isLoadingMore = false
    @Published private(set) var error: Error?
    @Published private(set) var hasMorePages = true
    
    private let articleCacheDuration: TimeInterval = 7 * 24 * 60 * 60  // 1 week
    private let articlesPerPage = 4
    private let prefetchThreshold = 2 // Start prefetching when user is 2 items from end
    private var currentPage = 0
    private var totalArticlesCount = 0
    
    private let supabase = SupabaseService.shared
    private let logger = Logger(subsystem: "com.gw.PoloLifestyle", category: "ArticleViewModel")
    private let context = PersistenceController.shared.container.viewContext
    var fetchTask: Task<Void, Never>?  // Store the ongoing fetch task
    var prefetchTask: Task<Void, Never>?  // Store the ongoing prefetch task

    init() {
        loadCachedData()
    }
    
    func hasCachedData() async -> Bool {
        let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            logger.error("Failed to check cached data: \(error)")
            return false
        }
    }

    private func loadCachedData() {
        Task {
            let articleFetch = NSFetchRequest<CDArticle>(entityName: "CDArticle")
            // Don't sort by lastFetchedAt - get all articles and sort by creation date
            articleFetch.fetchLimit = articlesPerPage // Only load first page from cache

            do {
                let cdArticles = try context.fetch(articleFetch)
                if !cdArticles.isEmpty {
                    await MainActor.run {
                        // Convert to articles and sort by publish date (creation date)
                        self.articles = cdArticles
                            .map { $0.toArticle() }
                            .sorted { $0.publishDate > $1.publishDate }
                        // Show cached content immediately for better UX
                    }
                }
            } catch {
                logger.error("Failed to load cached data: \(error)")
            }
        }
    }
    
    // MARK: - Pagination Methods
    
    func fetchInitialArticles(forceRefresh: Bool = false) async {
        // Reset pagination state
        currentPage = 0
        articles = []
        hasMorePages = true
        
        if forceRefresh {
            // Clear cache and force fetch from server
            await clearCache()
            await fetchArticlesPage(page: currentPage, isInitial: true)
        } else {
            await fetchArticles(forceRefresh: forceRefresh)
        }
    }
    
    private func clearCache() async {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "CDArticle"))
        do {
            _ = try context.execute(deleteRequest)
            saveContext()
        } catch {
            logger.error("Failed to clear cache: \(error)")
        }
    }
    
    func loadMoreArticles() async {
        guard hasMorePages && !isLoadingMore else { return }
        
        currentPage += 1
        await fetchArticlesPage(page: currentPage, isInitial: false)
    }
    
    func shouldLoadMore(currentItem: Article) -> Bool {
        guard let itemIndex = articles.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }
        
        return itemIndex >= articles.count - prefetchThreshold
    }
    
    private func fetchArticlesPage(page: Int, isInitial: Bool) async {
        let offset = page * articlesPerPage
        
        if isInitial {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        error = nil
        
        let task = Task {
            do {
                // First, get the total count
                if isInitial {
                    let countResponse = try await supabase.client
                        .database
                        .from("articles")
                        .select("id", head: false, count: .exact)
                        .execute()
                    
                    totalArticlesCount = countResponse.count ?? 0
                }
                
                // Fetch paginated articles
                let response = try await supabase.client
                    .database
                    .from("articles")
                    .select()
                    .order("created_at", ascending: false)
                    .range(from: offset, to: offset + articlesPerPage - 1)
                    .execute()
                
                let decoder = JSONDecoder()
                let originalArticles = try decoder.decode([Article].self, from: response.data)
                
                // Create articles with converted filenames for UI
                var articlesForUI: [Article] = []
                for article in originalArticles {
                    var uiArticle = article
                    let titleImageFilename = "\(article.id).jpg"
                    uiArticle.titleImage = titleImageFilename // Convert to filename for UI
                    articlesForUI.append(uiArticle)
                    print("🎨 UI Article \(article.id): titleImage set to \(titleImageFilename)")
                }
                
                await MainActor.run {
                    if isInitial {
                        self.articles = articlesForUI
                    } else {
                        // Filter out duplicates before appending
                        let uniqueNewArticles = articlesForUI.filter { newArticle in
                            !self.articles.contains { $0.id == newArticle.id }
                        }
                        self.articles.append(contentsOf: uniqueNewArticles)
                    }
                    
                    // Update hasMorePages based on response
                    self.hasMorePages = originalArticles.count == self.articlesPerPage && 
                                       self.articles.count < self.totalArticlesCount
                    
                    if isInitial {
                        self.isLoading = false
                    } else {
                        self.isLoadingMore = false
                    }
                }
                
                // Only download images for visible articles (first 4-6 items) using original URLs
                let imagesToDownload = isInitial ? min(6, originalArticles.count) : min(2, originalArticles.count)
                await downloadImagesForOriginalArticles(Array(originalArticles.prefix(imagesToDownload)), startIndex: offset)
                
                // Also download section images for these articles
                await downloadSectionImagesForArticles(Array(originalArticles.prefix(imagesToDownload)))
                
            } catch {
                await MainActor.run {
                    self.error = error
                    if isInitial {
                        self.isLoading = false
                    } else {
                        self.isLoadingMore = false
                    }
                }
                logger.error("Failed to fetch articles page: \(error)")
            }
        }
        
        if isInitial {
            fetchTask = task
        } else {
            prefetchTask = task
        }
    }
    
    private func downloadImagesForOriginalArticles(_ originalArticles: [Article], startIndex: Int) async {
        for (index, article) in originalArticles.enumerated() {
            let imageName = "\(article.id).jpg"
            let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)
            
            // Only download if image doesn't exist
            if !FileManager.default.fileExists(atPath: imagePath.path) {
                if let imageUrl = URL(string: article.titleImage) {
                    print("⬇️ Downloading title image for article \(article.id): \(article.titleImage) -> \(imageName)")
                    
                    // Find existing CoreData article or create new one
                    let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", article.id)
                    
                    do {
                        let existingArticles = try context.fetch(fetchRequest)
                        let cdArticle: CDArticle
                        
                        if let existingArticle = existingArticles.first {
                            cdArticle = existingArticle
                        } else {
                            cdArticle = article.toCoreData(context: context, updatedSections: [])
                        }
                        
                        cdArticle.titleImage = imageName // Store filename, not URL
                        await downloadAndSaveImage(from: imageUrl, for: cdArticle, atIndex: startIndex + index)
                        print("✅ Successfully set title image filename: \(imageName) for article \(article.id)")
                    } catch {
                        print("❌ Error updating title image for article \(article.id): \(error)")
                    }
                } else {
                    print("❌ Invalid title image URL for article \(article.id): \(article.titleImage)")
                }
            } else {
                print("✅ Title image already exists for article \(article.id): \(imageName)")
            }
        }
        saveContext()
    }
    
    private func downloadSectionImagesForArticles(_ originalArticles: [Article]) async {
        print("🖼️ Starting section image download for \(originalArticles.count) articles")
        
        for article in originalArticles {
            guard let sections = article.sections else { continue }
            
            var updatedSections: [Article.Section] = []
            
            for section in sections {
                guard let images = section.images else { 
                    // No images in this section, keep as is
                    updatedSections.append(section)
                    continue 
                }
                
                print("🖼️ Article \(article.id): Found \(images.count) section images")
                
                var localImagePaths: [String] = []
                
                for imageUrlString in images {
                    if let imageUrl = URL(string: imageUrlString) {
                        let imageName = UUID().uuidString + ".jpg"
                        print("⬇️ Downloading section image: \(imageUrlString) -> \(imageName)")
                        
                        if let localPath = await saveSectionImageLocally(from: imageUrl, withName: imageName) {
                            print("✅ Successfully saved section image: \(localPath)")
                            localImagePaths.append(localPath)
                        } else {
                            print("❌ Failed to save section image: \(imageUrlString)")
                            // Keep original URL if download failed
                            localImagePaths.append(imageUrlString)
                        }
                    } else {
                        print("❌ Invalid section image URL: \(imageUrlString)")
                        localImagePaths.append(imageUrlString)
                    }
                }
                
                // Create updated section with local image paths
                updatedSections.append(Article.Section(
                    subheading: section.subheading, 
                    text: section.text, 
                    images: localImagePaths
                ))
            }
            
            // Find existing CoreData article or create new one
            let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
            fetchRequest.predicate = NSPredicate(format: "id == %@", article.id)
            
            do {
                let existingArticles = try context.fetch(fetchRequest)
                let cdArticle: CDArticle
                
                if let existingArticle = existingArticles.first {
                    cdArticle = existingArticle
                } else {
                    cdArticle = article.toCoreData(context: context, updatedSections: updatedSections)
                }
                
                // Update with new sections
                cdArticle.lastFetchedAt = Date()
                
                // Convert updated sections to CoreData format
                if let sectionsData = try? JSONEncoder().encode(updatedSections) {
                    cdArticle.sectionsData = sectionsData
                    print("🔄 Updated sections for article \(article.id) with \(updatedSections.count) sections")
                    for (index, section) in updatedSections.enumerated() {
                        if let images = section.images, !images.isEmpty {
                            print("✅ Section \(index): \(images.count) images - \(images.prefix(2))")
                        }
                    }
                }
                
            } catch {
                print("❌ Error updating CoreData for article \(article.id): \(error)")
            }
        }
        
        saveContext()
        
        // Refresh UI with updated articles from CoreData
        await MainActor.run {
            self.refreshArticlesFromCoreData()
        }
        
        print("🖼️ Completed section image download and CoreData update")
    }
    
    private func refreshArticlesFromCoreData() {
        let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "lastFetchedAt", ascending: false)]
        
        do {
            let cdArticles = try context.fetch(fetchRequest)
            let refreshedArticles = cdArticles.map { $0.toArticle() }
            
            // Update only the sections, preserve title images that were already converted
            for (index, currentArticle) in articles.enumerated() {
                if let updatedArticle = refreshedArticles.first(where: { $0.id == currentArticle.id }) {
                    var mergedArticle = updatedArticle
                    
                    // Preserve the converted title image filename if it exists locally
                    let titleImageFilename = "\(currentArticle.id).jpg"
                    let imagePath = getDocumentsDirectory().appendingPathComponent(titleImageFilename)
                    if FileManager.default.fileExists(atPath: imagePath.path) {
                        mergedArticle.titleImage = titleImageFilename
                        print("✅ Preserved title image: \(titleImageFilename) for article \(currentArticle.id)")
                    } else {
                        mergedArticle.titleImage = updatedArticle.titleImage
                        print("⚠️ Using CoreData title image: \(updatedArticle.titleImage) for article \(currentArticle.id)")
                    }
                    
                    articles[index] = mergedArticle
                    print("🔄 Refreshed article \(currentArticle.id) with updated sections")
                    
                    // Debug: Print section images to verify they're updated
                    if let sections = mergedArticle.sections {
                        for (sectionIndex, section) in sections.enumerated() {
                            if let images = section.images, !images.isEmpty {
                                print("🖼️ Updated Section \(sectionIndex): \(images.count) images - \(images.prefix(2))")
                            }
                        }
                    }
                }
            }
            
            // Trigger UI update
            objectWillChange.send()
            
        } catch {
            logger.error("Failed to refresh articles from CoreData: \(error)")
        }
    }

    func fetchArticles(forceRefresh: Bool = false) async {
        let isValid = self.fetchArticlesFromCoreData(forceRefresh: forceRefresh)
        
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

        // Use new pagination method
        await fetchArticlesPage(page: currentPage, isInitial: true)
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
            print("❌ Cannot get documents directory")
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(imageName)
        let fileExists = fileManager.fileExists(atPath: fileURL.path)
        print("📷 fetchImageFromDocumentsDirectory: \(imageName) -> exists: \(fileExists) at \(fileURL.path)")
        
        return fileURL
    }
    
    // MARK: - On-demand Image Loading
    
    func downloadImageIfNeeded(for article: Article) async {
        // Create proper filename from article ID
        let imageName = "\(article.id).jpg"
        let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)
        
        print("🔍 Checking image for article \(article.id): \(imageName)")
        print("📁 Image path: \(imagePath.path)")
        print("📋 File exists: \(FileManager.default.fileExists(atPath: imagePath.path))")
        
        // If image doesn't exist locally, download it
        if !FileManager.default.fileExists(atPath: imagePath.path) {
            print("⬇️ Downloading image for article \(article.id)")
            // Get original URL from server for this specific article
            await downloadImageFromServer(articleId: article.id, imageName: imageName)
        } else {
            print("✅ Image already exists for article \(article.id)")
        }
    }
    
    private func downloadImageFromServer(articleId: String, imageName: String) async {
        do {
            // Fetch the specific article from server to get original URL
            let response = try await supabase.client
                .database
                .from("articles")
                .select()
                .eq("id", value: articleId)
                .execute()
            
            let decoder = JSONDecoder()
            let serverArticles = try decoder.decode([Article].self, from: response.data)
            
            guard let serverArticle = serverArticles.first else {
                logger.error("Article with id \(articleId) not found on server")
                return
            }
            
            // Download using original URL
            if let imageUrl = URL(string: serverArticle.titleImage) {
                logger.info("Downloading image from: \(serverArticle.titleImage)")
                let (data, _) = try await URLSession.shared.data(from: imageUrl)
                let imagePath = getDocumentsDirectory().appendingPathComponent(imageName)
                try data.write(to: imagePath)
                
                logger.info("Successfully downloaded and saved image: \(imageName)")
                
                // Save to CoreData
                let cdArticle = serverArticle.toCoreData(context: context, updatedSections: [])
                cdArticle.titleImage = imageName
                saveContext()
                
                // Trigger UI refresh
                await MainActor.run {
                    self.objectWillChange.send()
                }
            } else {
                logger.error("Invalid image URL for article \(articleId): \(serverArticle.titleImage)")
            }
        } catch {
            logger.error("Failed to download image for article \(articleId): \(error)")
        }
    }
}

extension Date {
    func convertToUTC() -> Date {
        let timeZoneOffset = TimeInterval(TimeZone.current.secondsFromGMT(for: self))
        return self.addingTimeInterval(-timeZoneOffset)
    }
}
