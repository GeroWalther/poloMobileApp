import Foundation
import Combine
import OSLog
import CoreData
import UIKit

@MainActor
class MagazineViewModel: ObservableObject {
    @Published private(set) var magazines: [Magazine] = []
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let supabase = SupabaseService.shared
    private let logger = Logger(subsystem: "com.gw.PoloLifestyle", category: "MagazineViewModel")
    private let context = PersistenceController.shared.container.viewContext
    var fetchTask: Task<Void, Never>?  // Store the ongoing fetch task

    private let articleCacheDuration: TimeInterval = 7 * 24 * 60 * 60  // 1 week
    private let magazineFetchDates: [Int] = [1, 4, 7, 10] // Quarterly fetch months (Jan, Apr, Jul, Oct)

    init() {
        loadCachedData()
    }

    private func loadCachedData() {
        Task {
            let currentDate = Date()

            let magazineFetch = NSFetchRequest<CDMagazine>(entityName: "CDMagazine")
            magazineFetch.predicate = NSPredicate(format: "lastFetchedAt > %@", getLastQuarterDate() as NSDate)

            let articleFetch = NSFetchRequest<CDArticle>(entityName: "CDArticle")
            articleFetch.predicate = NSPredicate(format: "lastFetchedAt > %@", currentDate.addingTimeInterval(-articleCacheDuration) as NSDate)

            do {
                let cdMagazines = try context.fetch(magazineFetch)
                let cdArticles = try context.fetch(articleFetch)

                await MainActor.run {
                    self.magazines = cdMagazines.map { $0.toMagazine() }
                    self.articles = cdArticles.map { $0.toArticle() }
                }
            } catch {
                logger.error("Failed to load cached data: \(error)")
            }
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
        let currentDate = Date()

        // Check cached magazines
        let fetchRequest = NSFetchRequest<CDMagazine>(entityName: "CDMagazine")
        do {
            let storedMagazines = try context.fetch(fetchRequest)
            
            if !storedMagazines.isEmpty, !forceRefresh {
                //let lastFetchedAt = storedMagazines.first?.lastFetchedAt ?? Date.distantPast
                let lastQuarterlySync = storedMagazines.first?.lastQuarterlySync ?? Date.distantPast
                let isQuarterlyFetchRequired = shouldFetchQuarterly(lastFetchedAt: lastQuarterlySync)
                
                // ✅ If no refresh is needed and no quarterly fetch is due, use cache
                if !forceRefresh && !isQuarterlyFetchRequired {
                    logger.debug("Using cached magazines")
                    DispatchQueue.main.async {
                        self.magazines = storedMagazines.map { $0.toMagazine() }
                    }
                    return
                }
            }
        } catch {
            logger.error("CoreData fetch failed: \(error)")
        }

        
        // ✅ Check internet connection before making request
        if !isInternetAvailable() {
            return
        }
        
        if isLoading { return }

        isLoading = true
        error = nil

        fetchTask = Task {
            do {
                let response = try await supabase.client
                    .database
                    .from("magazines")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()
                
                let decoder = JSONDecoder()
                let newMagazines = try decoder.decode([Magazine].self, from: response.data)
                
                // ✅ Immediately update UI with new magazines (without PDFs yet)
                DispatchQueue.main.async {
                    self.magazines = newMagazines
                }
                
                // ✅ Delete old magazines
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "CDMagazine"))
                _ = try? context.execute(deleteRequest)
                
                // ✅ Save new magazines
                for magazine in newMagazines {
                    let cdMagazine = magazine.toCoreData(context: context)
                    await savePDF(magazine: magazine, cdMagazine: cdMagazine)
                }
                
                saveContext()
                
                DispatchQueue.main.async {
                     self.error = nil
                    self.isLoading = false
                    self.logger.info("Successfully fetched \(newMagazines.count) magazines")
                }
            } catch {
                if (error as NSError).code == -999 { return }  // Ignore cancellation errors
                DispatchQueue.main.async {
                     self.error = error
                    self.isLoading = false
                }
                logger.error("Failed to fetch magazines: \(error)")
            }
        }
    }

    func fetchArticles(forceRefresh: Bool = false) async {
        
        let isValid = self.fetchArticlesFromCoreData(forceRefresh: forceRefresh)
        if !isInternetAvailable() || isLoading || (isValid == true && forceRefresh == false){ return }

        isLoading = true
        error = nil

        fetchTask = Task {
            do {
                let response = try await supabase.client
                    .database
                    .from("articles")
                    .select()
                    .order("created_at", ascending: false)
                    .execute()

                let decoder = JSONDecoder()
                let newArticles = try decoder.decode([Article].self, from: response.data)

                let deleteRequest = NSBatchDeleteRequest(fetchRequest: NSFetchRequest<NSFetchRequestResult>(entityName: "CDArticle"))
                _ = try? context.execute(deleteRequest)

                for (index, article) in newArticles.enumerated() {
                    var updatedSections: [Article.Section] = []

                    for section in article.sections ?? [] {
                        var localImagePaths: [String] = []
                        for imageUrlString in section.images ?? [] {
                            if let imageUrl = URL(string: imageUrlString) {
                                let imageName = UUID().uuidString + ".jpg"
                                if let localPath = await saveImageLocally(from: imageUrl, withName: imageName) {
                                    localImagePaths.append(localPath)
                                }
                            }
                        }
                        updatedSections.append(Article.Section(subheading: section.subheading, text: section.text, images: localImagePaths))
                    }

                    let cdArticle = article.toCoreData(context: context, updatedSections: updatedSections)
                    cdArticle.lastFetchedAt = Date()
                    
                    if let imageUrl = URL(string: article.titleImage) {
                        await downloadAndSaveImage(from: imageUrl, for: cdArticle, atIndex: index)
                    }
                }
                saveContext()

                DispatchQueue.main.asyncAfter(deadline: .now()) {
                    self.isLoading = false
                    let _ = self.fetchArticlesFromCoreData()
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error
                    self.isLoading = false
                }
                print("Failed to fetch articles: \(error)")
            }
        }
    }
    
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
                        self.articles = storedArticles.map { $0.toArticle() }.sorted { $0.publishDate > $1.publishDate }
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
    
    private func savePDF(magazine: Magazine, cdMagazine: CDMagazine) async {
        guard let url = URL(string: magazine.pdf) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let fileName = "magazine_\(magazine.id).pdf"
            let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)

            try data.write(to: fileURL)

            DispatchQueue.main.async {
                // ✅ Update Core Data
                cdMagazine.pdf = fileName
                self.saveContext()

                // ✅ Find the magazine in the list and update it
                if let index = self.magazines.firstIndex(where: { $0.id == magazine.id }) {
                    var updatedMagazine = self.magazines[index]
                    updatedMagazine.pdf = fileName
                    self.magazines[index] = updatedMagazine  // ✅ Triggers SwiftUI refresh
                }
            }
        } catch {
            logger.error("Failed to download PDF for magazine \(magazine.id): \(error)")
        }
    }


    func saveImageLocally(from url: URL, withName name: String) async -> String? {
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

    /// Returns the last quarterly fetch date
    private func getLastQuarterDate() -> Date {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let year = Calendar.current.component(.year, from: Date())
        let lastFetchMonth = magazineFetchDates.last(where: { $0 <= currentMonth }) ?? 1
        let components = DateComponents(year: year, month: lastFetchMonth, day: 2)
        return Calendar.current.date(from: components) ?? Date()
    }

    func refreshAll() async {
        await fetchMagazines(forceRefresh: true)
        await fetchArticles(forceRefresh: true)
    }
    
    func fetchMagazineFromDocuments(fileName: String) -> URL? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
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
    
    func fetchImageFromDocumentsDirectory(imageName: String) -> URL? {
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsDirectory.appendingPathComponent(imageName)
        return fileURL
    }
}
