import Foundation

struct PDFCache {
    static let shared = PDFCache()
    
    let cache: URLCache
    
    private init() {
        let diskPath = "PDFCache"
        let cacheSize = 50 * 1024 * 1024 // 50MB cache
        cache = URLCache(memoryCapacity: cacheSize,
                        diskCapacity: cacheSize,
                        diskPath: diskPath)
        URLCache.shared = cache
    }
} 