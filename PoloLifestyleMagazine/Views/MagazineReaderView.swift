import SwiftUI
import PDFKit

struct MagazineReaderView: View {
    let magazine: Magazine
    @State private var pdfDocument: PDFDocument?
    @State private var currentPage = 0
    @State private var totalPages = 0
    @State private var isLoading = true
    @State private var loadingError: Error?
    @State private var opacity = 1.0
    @State private var scale = 1.0
    
    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            
            ZStack {
                // Light grey background
                Color(UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0))
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let error = loadingError {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                        Text("Failed to load PDF")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .padding()
                        Button("Try Again") {
                            loadPDF()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    // PDF View
                    PDFPagesView(document: pdfDocument,
                               currentPage: $currentPage,
                               totalPages: $totalPages,
                               isLandscape: isLandscape)
                    .opacity(opacity)
                    .scaleEffect(scale)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Smooth transition while dragging
                                let dragPercentage = abs(value.translation.width / geometry.size.width)
                                opacity = 1.0 - (dragPercentage * 0.15) // Reduced fade
                                scale = 1.0 - (dragPercentage * 0.05) // Subtle scale
                            }
                            .onEnded { value in
                                let threshold = geometry.size.width * 0.2
                                let pageIncrement = isLandscape ? 2 : 1
                                
                                if abs(value.translation.width) > threshold {
                                    // Smooth page change animation
                                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                        opacity = 0.85
                                        scale = 0.95
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        if value.translation.width > threshold && currentPage > 0 {
                                            currentPage = max(0, currentPage - pageIncrement)
                                        } else if value.translation.width < -threshold && currentPage < totalPages - 1 {
                                            currentPage = min(totalPages - 1, currentPage + pageIncrement)
                                        }
                                        
                                        withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                            opacity = 1.0
                                            scale = 1.0
                                        }
                                    }
                                } else {
                                    // Reset with spring animation
                                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 30)) {
                                        opacity = 1.0
                                        scale = 1.0
                                    }
                                }
                            }
                    )
                    
                    // Page counter at bottom with blur effect
                    VStack {
                        Spacer()
                        Text("Page \(currentPage + 1) of \(totalPages)")
                            .foregroundColor(.black)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                            .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPDF()
        }
    }
    
    private func loadPDF() {
        guard let url = URL(string: magazine.pdf) else {
            loadingError = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            isLoading = false
            return
        }
        
        isLoading = true
        loadingError = nil
        
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    loadingError = error
                } else if let data = data, let document = PDFDocument(data: data) {
                    pdfDocument = document
                    totalPages = document.pageCount
                } else {
                    loadingError = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load PDF"])
                }
                isLoading = false
            }
        }.resume()
    }
}

struct PDFPagesView: UIViewRepresentable {
    let document: PDFDocument?
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    let isLandscape: Bool
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        
        // Configure for magazine-style layout
        pdfView.displayMode = isLandscape ? .twoUp : .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(false)
        
        // Set grey background color
        pdfView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0) // Light grey
        pdfView.pageBreakMargins = .zero
        
        // Add a subtle shadow to the pages
        if let scrollView = pdfView.subviews.first as? UIScrollView {
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.bounces = false
            
            // Find the PDF content view and add shadow
            for subview in scrollView.subviews {
                subview.layer.shadowColor = UIColor.black.cgColor
                subview.layer.shadowOpacity = 0.2
                subview.layer.shadowOffset = CGSize(width: 0, height: 2)
                subview.layer.shadowRadius = 4
            }
        }
        
        // Configure delegate
        pdfView.delegate = context.coordinator
        
        // Set document and initial page
        pdfView.document = document
        if let document = document {
            totalPages = document.pageCount
            if let firstPage = document.page(at: currentPage) {
                pdfView.go(to: firstPage)
            }
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        guard let document = pdfView.document else { return }
        
        pdfView.displayMode = isLandscape ? .twoUp : .singlePage
        
        if let page = document.page(at: currentPage) {
            pdfView.go(to: page)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PDFViewDelegate {
        let parent: PDFPagesView
        
        init(_ parent: PDFPagesView) {
            self.parent = parent
        }
        
        func pdfViewPageChanged(_ pdfView: PDFView) {
            guard let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            let pageIndex = document.index(for: currentPage)
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
    }
} 