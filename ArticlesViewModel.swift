import Foundation

@MainActor
class ArticlesViewModel: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isRefetching = false
    @Published private(set) var error: Error?
    @Published private(set) var isInitialized = false
    
    private let supabase = SupabaseService.shared
    private let context = PersistenceController.shared.container.viewContext
    private let cacheTimeout: TimeInterval = 3 // 3 seconds
    
    init() {
        print("📊 ARTICLES: ViewModel initialized")
        Task {
            print("📊 ARTICLES: Starting initial load")
            await loadArticles(forceRefresh: true)
        }
    }
    
    private func initialLoad() async {
        print("🚀 INITIAL LOAD STARTED")
        isLoading = true
        
        do {
            print("🌐 Fetching initial articles...")
            let articles = try await supabase.client.database
                .from("articles")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("📥 Initial fetch: \(articles.count) articles")
            await MainActor.run {
                self.articles = articles.sorted { $0.publishDate > $1.publishDate }
                self.isLoading = false
                self.isInitialized = true
                print("✅ Initial load complete - UI updated")
            }
        } catch {
            print("❌ Initial load error:", error)
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    func loadArticles(forceRefresh: Bool = false) async {
        print("\n📊 ARTICLES: Load requested (forceRefresh: \(forceRefresh))")
        
        // Check cache first
        let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        do {
            let storedArticles = try context.fetch(fetchRequest)
            let lastFetchedAt = storedArticles.first?.lastFetchedAt ?? .distantPast
            let cacheAge = Date().timeIntervalSince(lastFetchedAt)
            
            print("📊 ARTICLES: Cache status:")
            print("  • Articles in cache: \(storedArticles.count)")
            print("  • Cache age: \(String(format: "%.1f", cacheAge)) seconds")
            print("  • Cache timeout: \(cacheTimeout) seconds")
            
            if !forceRefresh && !storedArticles.isEmpty && cacheAge <= cacheTimeout {
                print("📊 ARTICLES: Using cached data")
                self.articles = storedArticles.map { $0.toArticle() }
                print("📊 ARTICLES: UI updated with \(self.articles.count) cached articles")
                return
            }
            
            print("📊 ARTICLES: Cache invalid or force refresh - fetching from network")
            isRefetching = true
            
            print("📊 ARTICLES: Network fetch started")
            let articles = try await supabase.client.database
                .from("articles")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("📊 ARTICLES: Network fetch completed - \(articles.count) articles")
            
            print("📊 ARTICLES: Clearing old cache")
            try context.execute(NSBatchDeleteRequest(fetchRequest: fetchRequest))
            
            print("📊 ARTICLES: Saving to cache")
            for article in articles {
                let cdArticle = article.toCoreData(context: context)
                cdArticle.lastFetchedAt = Date()
            }
            try context.save()
            print("📊 ARTICLES: Cache updated")
            
            self.articles = articles
            print("📊 ARTICLES: UI updated with \(articles.count) fresh articles")
            
        } catch {
            print("📊 ARTICLES: ERROR - \(error.localizedDescription)")
        }
        
        isRefetching = false
        print("📊 ARTICLES: Load completed\n")
    }
} 