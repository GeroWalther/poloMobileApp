//
//  PoloLifestyleMagazineApp.swift
//  PoloLifestyleMagazine
//
//  Created by Gero Walther on 11/1/25.
//

import SwiftUI

@main
struct PoloLifestyleMagazineApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Initialize Supabase service
    let supabase = SupabaseService.shared
    let pdfCache = PDFCache.shared
    
    init() {
        // Register the secure transformer
        ArticleImagesTransformer.register()
        
        // Configure navigation bar appearance
        let navBarAppearance = UINavigationBarAppearance()
        
        // Configure background
        navBarAppearance.configureWithOpaqueBackground()
        navBarAppearance.backgroundColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        
        // Set larger height for navigation bar
        let heightIncrease: CGFloat = 45
        let bounds = UINavigationBar.appearance().bounds
        UINavigationBar.appearance().frame = CGRect(x: bounds.origin.x, 
                                                  y: bounds.origin.y, 
                                                  width: bounds.width, 
                                                  height: bounds.height + heightIncrease)
        
        // Configure text attributes for title
        navBarAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
        ]
        
        navBarAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0),
        ]
        
        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .white
        
        // Set both selected (tint) and unselected colors
        UITabBar.appearance().tintColor = UIColor(red: 0.6, green: 0.4, blue: 0.0, alpha: 1.0) // #996600 for selected
        UITabBar.appearance().unselectedItemTintColor = UIColor.gray // for unselected
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
        
        // Apply the appearance to all navigation bars
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(MagazineViewModel())
                .environmentObject(ArticleViewModel())
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        NotificationService.shared.requestPermission()
        return true
    }
}
