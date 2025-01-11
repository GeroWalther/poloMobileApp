//
//  PoloLifestyleMagazineApp.swift
//  PoloLifestyleMagazine
//
//  Created by Gero Walther on 11/1/25.
//

import SwiftUI

@main
struct PoloLifestyleMagazineApp: App {
    // Initialize Supabase service
    let supabase = SupabaseService.shared
    let pdfCache = PDFCache.shared
    
    init() {
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        
        // Configure background
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0)
        
        // Configure text attributes for large title - Dark Grey
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0), // Dark grey for POLO&Lifestyle
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        
        // Configure text attributes for standard title
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0), // Dark grey
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        
        // Apply the appearance to all navigation bars
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(MagazineViewModel())
        }
    }
}
