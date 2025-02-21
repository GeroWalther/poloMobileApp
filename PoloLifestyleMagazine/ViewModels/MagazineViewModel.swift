import Foundation
import Combine
import OSLog
import CoreData
import UIKit

@MainActor
class MagazineViewModel: ObservableObject {
    @Published private(set) var magazines: [Magazine] = []
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


            do {
                let cdMagazines = try context.fetch(magazineFetch)

                await MainActor.run {
                    self.magazines = cdMagazines.map { $0.toMagazine() }
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

    
    func fetchMagazineFromDocuments(fileName: String) -> URL? {
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
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
