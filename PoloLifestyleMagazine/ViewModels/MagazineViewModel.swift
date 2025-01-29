import Foundation
import Combine
import OSLog

@MainActor
class MagazineViewModel: ObservableObject {
    @Published private(set) var magazines: [Magazine] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published private(set) var articles: [Article] = []
    
    private let supabase = SupabaseService.shared
    private let logger = Logger(subsystem: "com.gw.PoloLifestyle", category: "MagazineViewModel")
    
    func fetchMagazines() async {
        if isLoading { return }  // Prevent multiple simultaneous fetches
        
        isLoading = true
        error = nil
        
        do {
            let response = try await supabase.client
                .database
                .from("magazines")
                .select()
                .order("created_at", ascending: false)
                .execute()
            
            let decoder = JSONDecoder()
            let newMagazines = try decoder.decode([Magazine].self, from: response.data)
            
            // Update state in a single batch
            await MainActor.run {
                self.magazines = newMagazines
                self.error = nil
                self.isLoading = false
            }
            
            // Log after state updates
            logger.info("Successfully fetched \(newMagazines.count) magazines")
            
            #if DEBUG
            if let jsonString = String(data: response.data, encoding: .utf8) {
                logger.debug("Raw JSON response: \(jsonString)")
            }
            
            for magazine in newMagazines {
                logger.debug("""
                    Magazine:
                    - Title: \(magazine.title)
                    - ID: \(magazine.id)
                    - Description: \(magazine.description)
                    - PDF URL: \(magazine.pdf)
                    - Created at: \(magazine.createdAt)
                    ---
                    """)
            }
            #endif
            
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
            logger.error("Failed to fetch magazines: \(error)")
        }
    }
    
    func fetchArticles() async {
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
            
            logger.debug("Got response from Supabase")
            
            #if DEBUG
            if let jsonString = String(data: response.data, encoding: .utf8) {
                logger.debug("Raw JSON response for articles: \(jsonString)")
                
                // Try to parse the raw response to see what we're getting
                do {
                    let anyJson = try JSONSerialization.jsonObject(with: response.data)
                    logger.debug("Raw response structure: \(String(describing: anyJson))")
                } catch {
                    logger.error("Failed to parse raw JSON: \(error)")
                }
            }
            #endif
            
            let decoder = JSONDecoder()
            let newArticles = try decoder.decode([Article].self, from: response.data)
            
            await MainActor.run {
                self.articles = newArticles
                self.error = nil
                self.isLoading = false
            }
            
            logger.info("Successfully fetched \(newArticles.count) articles")
            
        } catch {
            logger.error("Failed to fetch articles: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
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