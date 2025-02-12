import Foundation
import Supabase

final class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        // Initialize Supabase client with your project credentials
        client = SupabaseClient(
            supabaseURL: URL(string: "https://jbbapowlexdnmmmnpzpy.supabase.co")!,
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpiYmFwb3dsZXhkbm1tbW5wenB5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzY1OTg3OTcsImV4cCI6MjA1MjE3NDc5N30.T5FWzzs4QkQnUleMEFoOictDQBWM3jLd7g7euUT9dZ0"
        )
    }
} 
