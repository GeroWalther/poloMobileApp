import SwiftUI
import PDFKit

struct MagazinesView: View {
    @StateObject private var viewModel = MagazineViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)),
                        Color(UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0))
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(viewModel.magazines) { magazine in
                            NavigationLink {
                                PDFKitView(url: URL(string: magazine.pdf)!)
                            } label: {
                                MagazineRowView(magazine: magazine)
                            }
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await viewModel.fetchMagazines(forceRefresh: true)
                }
            }
            .navigationTitle("Magazines")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.fetchMagazines()
            }
        }
    }
}

private struct MagazineRowView: View {
    let magazine: Magazine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(magazine.title)
                .font(.headline)
            Text(magazine.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let url = URL(string: magazine.pdf) {
                Link("View PDF", destination: url)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
    }
}

private struct PDFKitView: View {
    let url: URL
    
    var body: some View {
        PDFKitRepresentedView(url)
    }
}

// PDF view representation
private struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL
    
    init(_ url: URL) {
        self.url = url
    }
    
    func makeUIView(context: UIViewRepresentableContext<PDFKitRepresentedView>) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: UIViewRepresentableContext<PDFKitRepresentedView>) {
        // No need to update
    }
} 