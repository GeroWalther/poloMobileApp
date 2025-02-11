@MainActor
class MagazineViewModel: ObservableObject {
    @Published private(set) var isInitialized = false
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private(set) var isLoadingInitialData = true

    private let articleCacheValidityDuration: TimeInterval = 604_800 // 1 week in seconds

    init() {
        Task {
            await loadCachedData()
            isLoadingInitialData = false
        }
    }
    
    private func loadCachedData() async {
        let magazinesFetch = NSFetchRequest<CDMagazine>(entityName: "CDMagazine")
        let articlesFetch = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        
        // No time-based filtering, just load all cached data
        
        do {
            let cdMagazines = try context.fetch(magazinesFetch)
            let cdArticles = try context.fetch(articlesFetch)
            
            await MainActor.run {
                self.magazines = cdMagazines.map { $0.toMagazine() }
                self.articles = cdArticles.map { $0.toArticle() }
            }
        } catch {
            logger.error("Failed to load cached data: \(error)")
        }
        isInitialized = true
    }

    private func isArticleCacheValid() -> Bool {
        let articlesFetch = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        articlesFetch.predicate = NSPredicate(
            format: "lastFetchedAt > %@",
            Date().addingTimeInterval(-articleCacheValidityDuration) as NSDate
        )
        
        return (try? context.fetch(articlesFetch).count > 0) ?? false
    }

    private func isMagazineCacheValid() -> Bool {
        let calendar = Calendar.current
        
        // Get last quarterly update date
        let year = calendar.component(.year, from: Date())
        let currentQuarter = ((calendar.component(.month, from: Date()) - 1) / 3) * 3 + 1
        
        var components = DateComponents()
        components.year = year
        components.month = currentQuarter
        components.day = 2
        components.hour = 0
        components.minute = 0
        components.second = 0
        
        guard let quarterlyUpdateDate = calendar.date(from: components) else {
            return false
        }
        
        let magazinesFetch = NSFetchRequest<CDMagazine>(entityName: "CDMagazine")
        magazinesFetch.predicate = NSPredicate(
            format: "lastFetchedAt > %@",
            quarterlyUpdateDate as NSDate
        )
        
        return (try? context.fetch(magazinesFetch).count > 0) ?? false
    }

    func fetchMagazines(forceRefresh: Bool = false) async {
        while !isInitialized {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        
        // If we have valid cached data and don't need to force refresh, return early
        if !forceRefresh && !magazines.isEmpty && isMagazineCacheValid() {
            return  // Use cached data
        }
        
        // Otherwise fetch from network
        isLoading = true
        do {
            // Network fetch implementation...
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func fetchArticles(forceRefresh: Bool = false) async {
        // If we have valid cached data and don't need force refresh, return early
        if !forceRefresh && !articles.isEmpty && isArticleCacheValid() {
            return  // Use cached data
        }
        
        // Only try network if:
        // 1. We have no cache OR
        // 2. Cache is invalid OR
        // 3. Force refresh was requested
        guard NetworkMonitor.shared.isConnected else {
            return  // Use whatever we have if offline
        }
        
        isLoading = true
        do {
            // Network fetch implementation...
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func saveContext() {
        // Implementation of saveContext
    }

    func toCoreData(context: NSManagedObjectContext) -> CDMagazine {
        // Implementation of toCoreData
        return CDMagazine()
    }

    func toMagazine() -> Magazine {
        // Implementation of toMagazine
        return Magazine()
    }

    func toArticle() -> Article {
        // Implementation of toArticle
        return Article()
    }
} 