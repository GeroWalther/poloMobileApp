import SwiftUI
import PDFKit

struct PDFThumbnailView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var error: Error?
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.backgroundColor = .clear
        
        loadPDF(in: pdfView)
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
    
    private func loadPDF(in pdfView: PDFView) {
        DispatchQueue.main.async {
            isLoading = true
            error = nil
        }
        
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.error = error
                } else if let data = data, let document = PDFDocument(data: data) {
                    pdfView.document = document
                    if let firstPage = document.page(at: 0) {
                        pdfView.go(to: firstPage)
                    }
                } else {
                    self.error = NSError(domain: "", code: -1, 
                        userInfo: [NSLocalizedDescriptionKey: "Failed to load preview"])
                }
                isLoading = false
            }
        }.resume()
    }
} 
