import Foundation
import Combine
import CoreData
import OSLog

@MainActor
class MagazineViewModel: ObservableObject {
    @Published private(set) var magazines: [Magazine] = []
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private(set) var isInitialized = false
    @Published private(set) var isLoadingInitialData = true
    @Published private(set) var isRefetching = false

    private static let CACHE_DURATION: TimeInterval = 3 // 3 seconds for testing
    private let supabase = SupabaseService.shared
    private let context = PersistenceController.shared.container.viewContext
    private let logger = Logger(subsystem: "com.poloLifestyle", category: "Cache")
    private var lastFetchTimestamp: Date = .distantPast
    private var isVisible = false
    private var cacheCheckTimer: Timer?

    init() {
        print("🏁 MagazineViewModel init started")
        Task {
            print("📱 Init Task started")
            await loadCachedData()
            print("📚 loadCachedData completed")
            await checkQuarterlyUpdate()
            print("🔄 checkQuarterlyUpdate completed")
            await checkCacheAndFetchIfNeeded()
            print("✅ checkCacheAndFetchIfNeeded completed")
            
            // Setup foreground notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(checkQuarterlyUpdateOnForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
            print("👀 Foreground observer setup complete")
        }
    }
    
    @objc private func checkQuarterlyUpdateOnForeground() {
        print("🔄 App coming to foreground - Forcing refresh")
        Task {
            await checkQuarterlyUpdate()
            await fetchArticles(forceRefresh: true)  // Force refresh when coming to foreground
            print("✅ Foreground update completed")
        }
    }
    
    private func checkQuarterlyUpdate() async {
        let fetchRequest = NSFetchRequest<CDMagazine>(entityName: "CDMagazine")
        do {
            let storedMagazines = try context.fetch(fetchRequest)
            let lastQuarterlySync = storedMagazines.first?.lastQuarterlySync ?? Date.distantPast
            
            if shouldFetchQuarterly(lastFetchedAt: lastQuarterlySync) {
                await fetchMagazines(forceRefresh: true)
            }
        } catch {
            logger.error("Failed to check quarterly update: \(error)")
        }
    }
    
    private func loadCachedData() async {
        print("📚 Loading cached data...")
        let articleFetch = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        
        do {
            let cdArticles = try context.fetch(articleFetch)
            if let lastFetch = cdArticles.first?.lastFetchedAt {
                lastFetchTimestamp = lastFetch
                print("📚 Updated lastFetchTimestamp to: \(lastFetch)")
            }
            
            await MainActor.run {
                self.articles = cdArticles.map { $0.toArticle() }
                    .sorted { $0.publishDate > $1.publishDate }
            }
            print("📚 Loaded \(cdArticles.count) cached articles")
        } catch {
            print("❌ Failed to load cached data: \(error)")
        }
        isInitialized = true
    }

    private func isArticleCacheValid() -> Bool {
        let articlesFetch = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        articlesFetch.predicate = NSPredicate(
            format: "lastFetchedAt > %@",
            Date().addingTimeInterval(-Self.CACHE_DURATION) as NSDate
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
        guard !isRefetching else {
            print("🚫 FETCH ARTICLES: Already fetching, skipping")
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        print("""
        🔄 FETCH ARTICLES STARTED
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        • Force refresh: \(forceRefresh)
        • Current time: \(formatter.string(from: Date()))
        • Last fetch: \(formatter.string(from: lastFetchTimestamp))
        """)
        
        await MainActor.run {
            self.isRefetching = true
        }
        
        do {
            let articles = try await supabase.client.database
                .from("articles")
                .select()
                .order("publish_date", ascending: false)
                .execute()
                .value
            
            print("✅ Got \(articles.count) articles from network at \(formatter.string(from: Date()))")
            await updateCacheAndUI(with: articles, currentDate: Date())
            
        } catch {
            print("❌ Fetch failed: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isRefetching = false
            }
        }
    }

    private func updateCacheAndUI(with articles: [Article], currentDate: Date) async throws {
        // Update the last fetch timestamp when we get new data
        lastFetchTimestamp = currentDate
        
        let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try context.execute(deleteRequest)
        
        for article in articles {
            let cdArticle = article.toCoreData(context: context)
            cdArticle.lastFetchedAt = currentDate
        }
        
        try context.save()
        
        await MainActor.run {
            self.articles = articles.sorted { $0.publishDate > $1.publishDate }
            self.isRefetching = false
        }
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

    func setTabVisibility(isVisible: Bool) {
        self.isVisible = isVisible
        if isVisible {
            print("\n📱 TAB BECAME VISIBLE")
            startCacheCheck()
        } else {
            stopCacheCheck()
        }
    }

    private func startCacheCheck() {
        stopCacheCheck() // Clear any existing timer
        
        // Immediately check cache
        Task {
            await checkCacheAndFetchIfNeeded()
        }
        
        // Setup timer on main thread
        DispatchQueue.main.async { [weak self] in
            self?.cacheCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                Task { [weak self] in
                    await self?.checkCacheAndFetchIfNeeded()
                }
            }
            // Make sure timer stays active when scrolling
            RunLoop.current.add(self?.cacheCheckTimer!, forMode: .common)
        }
    }
    
    private func stopCacheCheck() {
        cacheCheckTimer?.invalidate()
        cacheCheckTimer = nil
    }

    func checkCacheAndFetchIfNeeded() async {
        let currentDate = Date()
        let cacheExpiryDate = lastFetchTimestamp.addingTimeInterval(Self.CACHE_DURATION)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        
        print("""
        🕒 CACHE VALIDATION CHECK
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        • Current time:     \(formatter.string(from: currentDate))
        • Last fetch:       \(formatter.string(from: lastFetchTimestamp))
        • Cache expires:    \(formatter.string(from: cacheExpiryDate))
        • Cache age:        \(String(format: "%.1f", currentDate.timeIntervalSince(lastFetchTimestamp))) seconds
        • Cache duration:   \(Self.CACHE_DURATION) seconds
        • Cache expired:    \(currentDate > cacheExpiryDate)
        """)
        
        // Force refresh if cache is expired
        if currentDate > cacheExpiryDate {
            print("🔄 FORCE REFRESHING: Cache expired")
            await fetchArticles(forceRefresh: true)
            return
        }
        
        let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        
        do {
            let storedArticles = try context.fetch(fetchRequest)
            let lastFetchedAt = storedArticles.first?.lastFetchedAt ?? .distantPast
            
            print("""
            📦 CACHE STATUS
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            • Articles in cache: \(storedArticles.count)
            • Last fetch: \(formatter.string(from: lastFetchedAt))
            • Cache age: \(String(format: "%.3f", currentDate.timeIntervalSince(lastFetchedAt))) seconds
            • Cache expired: \(lastFetchedAt <= cacheExpiryDate)
            """)
            
            let shouldForceRefresh = storedArticles.isEmpty || lastFetchedAt <= cacheExpiryDate
            
            if shouldForceRefresh {
                print("🔄 FORCE REFRESHING: Cache expired at \(formatter.string(from: cacheExpiryDate))")
                await fetchArticles(forceRefresh: true)
            } else {
                print("✅ USING CACHE: Valid until \(formatter.string(from: cacheExpiryDate))")
                await MainActor.run {
                    self.articles = storedArticles.map { $0.toArticle() }
                        .sorted { $0.publishDate > $1.publishDate }
                }
            }
        } catch {
            print("❌ CACHE CHECK ERROR: \(error.localizedDescription)")
            await fetchArticles(forceRefresh: true)
        }
    }
} 