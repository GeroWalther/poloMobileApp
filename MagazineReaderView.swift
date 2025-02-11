private func loadPDF() {
    guard let url = URL(string: magazine.pdf) else { return }
    
    let cachePath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("\(magazine.id).pdf")
    
    if let document = PDFDocument(url: cachePath) {
        pdfDocument = document
        return
    }
    
    // Only download if not cached
    URLSession.shared.downloadTask(with: url) { tempURL, _, _ in
        guard let tempURL = tempURL else { return }
        try? FileManager.default.moveItem(at: tempURL, to: cachePath)
        DispatchQueue.main.async {
            pdfDocument = PDFDocument(url: cachePath)
        }
    }.resume()
} 