import Foundation
import Combine
import OSLog
import CoreData

@MainActor
class MagazineViewModel: ObservableObject {
    @Published private(set) var magazines: [Magazine] = []
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let supabase = SupabaseService.shared
    private let logger = Logger(subsystem: "com.gw.PoloLifestyle", category: "MagazineViewModel")
    private let context = PersistenceController.shared.container.viewContext
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes
    
    init() {
        loadCachedData()
    }
    
    private func loadCachedData() {
        let magazinesFetch = NSFetchRequest<CDMagazine>(entityName: "CDMagazine")
        magazinesFetch.predicate = NSPredicate(
            format: "lastFetchedAt > %@",
            Date().addingTimeInterval(-cacheValidityDuration) as NSDate
        )
        
        let articlesFetch = NSFetchRequest<CDArticle>(entityName: "CDArticle")
        articlesFetch.predicate = NSPredicate(
            format: "lastFetchedAt > %@",
            Date().addingTimeInterval(-cacheValidityDuration) as NSDate
        )
        
        do {
            let cdMagazines = try context.fetch(magazinesFetch)
            magazines = cdMagazines.map { $0.toMagazine() }
            
            let cdArticles = try context.fetch(articlesFetch)
            articles = cdArticles.map { $0.toArticle() }
        } catch {
            logger.error("Failed to load cached data: \(error)")
        }
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
    
    func fetchMagazines(forceRefresh: Bool = false) async {
        if !forceRefresh {
            // First try to load from CoreData
            let fetchRequest = NSFetchRequest<CDMagazine>(entityName: "CDMagazine")
            fetchRequest.predicate = NSPredicate(
                format: "lastFetchedAt > %@",
                Date().addingTimeInterval(-cacheValidityDuration) as NSDate
            )
            
            do {
                let storedMagazines = try context.fetch(fetchRequest)
                if !storedMagazines.isEmpty {
                    logger.debug("Using cached magazines")
                    self.magazines = storedMagazines.map { $0.toMagazine() }
                    return
                }
            } catch {
                logger.error("CoreData fetch failed: \(error)")
            }
        }
        
        if isLoading { return }
        
        isLoading = true
        error = nil
        
        // Fetch from network
        do {
            let response = try await supabase.client
                .database
                .from("magazines")
                .select()
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            let newMagazines = try decoder.decode([Magazine].self, from: response.data)
            
            // Save to Core Data
            let batch = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "CDMagazine"))
            _ = try? context.execute(batch)
            
            newMagazines.forEach { magazine in
                _ = magazine.toCoreData(context: context)
            }
            saveContext()
            
            self.magazines = newMagazines
            self.error = nil
            self.isLoading = false
            
            logger.info("Successfully fetched \(newMagazines.count) magazines")
            
        } catch {
            self.error = error
            self.isLoading = false
            logger.error("Failed to fetch magazines: \(error)")
        }
    }
    
    func fetchArticles(forceRefresh: Bool = false) async {
        if !forceRefresh {
            let fetchRequest = NSFetchRequest<CDArticle>(entityName: "CDArticle")
            fetchRequest.predicate = NSPredicate(
                format: "lastFetchedAt > %@",
                Date().addingTimeInterval(-cacheValidityDuration) as NSDate
            )
            
            do {
                let storedArticles = try context.fetch(fetchRequest)
                if !storedArticles.isEmpty {
                    logger.debug("Using cached articles")
                    self.articles = storedArticles.map { $0.toArticle() }
                    return
                }
            } catch {
                logger.error("CoreData fetch failed: \(error)")
            }
        }
        
        if isLoading { return }
        
        isLoading = true
        error = nil
        
        do {
            logger.debug("Starting articles fetch...")
            
            let response = try await supabase.client
                .database
                .from("articles")
                .select()
                .execute()
            
            let decoder = JSONDecoder()
            let newArticles = try decoder.decode([Article].self, from: response.data)
            
            // Save to Core Data
            let batch = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "CDArticle"))
            _ = try? context.execute(batch)
            
            newArticles.forEach { article in
                _ = article.toCoreData(context: context)
            }
            saveContext()
            
            self.articles = newArticles
            self.error = nil
            self.isLoading = false
            
            logger.info("Successfully fetched \(newArticles.count) articles")
            
        } catch {
            self.error = error
            self.isLoading = false
            logger.error("Failed to fetch articles: \(error)")
        }
    }
    
    // Function to force refresh all data
    func refreshAll() async {
        await fetchMagazines(forceRefresh: true)
        await fetchArticles(forceRefresh: true)
    }
    
    func fetchArticlesDirectly() async {
        do {
            let baseURL = "https://jbbapowlexdnmmmnpzpy.supabase.co/rest/v1/articles"
            logger.debug("Fetching from URL: \(baseURL)")
            
            var request = URLRequest(url: URL(string: baseURL + "?select=*")!)
            
            // Add required headers
            let headers = [
                "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpiYmFwb3dsZXhkbm1tbW5wenB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY1OTg3OTcsImV4cCI6MjA1MjE3NDc5N30.T5FWzzs4QkQnUleMEFoOictDQBWM3jLd7g7euUT9dZ0",
                "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpiYmFwb3dsZXhkbm1tbW5wenB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY1OTg3OTcsImV4cCI6MjA1MjE3NDc5N30.T5FWzzs4QkQnUleMEFoOictDQBWM3jLd7g7euUT9dZ0",
                "Content-Type": "application/json",
                "Prefer": "return=representation"
            ]
            
            headers.forEach { key, value in
                request.addValue(value, forHTTPHeaderField: key)
            }
            
            logger.debug("Request headers: \(headers)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                logger.debug("Direct API Response Status: \(httpResponse.statusCode)")
                logger.debug("Response headers: \(httpResponse.allHeaderFields)")
            }
            
            if let jsonString = String(data: data, encoding: .utf8) {
                logger.debug("Direct API Response: \(jsonString)")
                
                // Try to parse as dictionary with explicit type annotation
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                    logger.debug("Parsed response structure: \(json)")
                }
            }
            
            // Try to decode the response
            let decoder = JSONDecoder()
            let articles = try decoder.decode([Article].self, from: data)
            logger.debug("Successfully decoded \(articles.count) articles")
            
        } catch {
            logger.error("Direct API call failed: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                logger.error("Decoding error: \(decodingError)")
            }
        }
    }
} 