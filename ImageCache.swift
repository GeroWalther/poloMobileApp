actor ImageCache {
    static let shared = ImageCache()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func image(for url: URL) -> Image? {
        let imagePath = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        guard let data = try? Data(contentsOf: imagePath),
              let uiImage = UIImage(data: data) else {
            return nil
        }
        return Image(uiImage: uiImage)
    }
    
    func insert(_ image: Image, for url: URL) {
        guard let uiImage = image.asUIImage(),
              let data = uiImage.pngData() else { return }
        
        let imagePath = cacheDirectory.appendingPathComponent(url.lastPathComponent)
        try? data.write(to: imagePath)
    }
} 