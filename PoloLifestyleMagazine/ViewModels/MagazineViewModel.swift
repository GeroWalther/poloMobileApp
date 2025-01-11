import Foundation
import Combine
import OSLog

@MainActor
class MagazineViewModel: ObservableObject {
    @Published private(set) var magazines: [Magazine] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
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
} 