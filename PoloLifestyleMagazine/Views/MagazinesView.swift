import SwiftUI
import PDFKit

struct MagazinesView: View {
    @StateObject private var viewModel = MagazineViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient with grey tones
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)), // Light grey
                        Color(UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0))  // Slightly darker grey
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.gray)
                            Text("Loading Magazines...")
                                .foregroundColor(.gray)
                                .font(.headline)
                        }
                    } else if let error = viewModel.error {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                            Text("Failed to load magazines")
                                .font(.headline)
                            Text(error.localizedDescription)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task {
                                    await viewModel.fetchMagazines()
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.gray)
                        }
                        .foregroundColor(.gray)
                    } else if viewModel.magazines.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "magazine")
                                .font(.system(size: 50))
                            Text("No magazines available")
                                .font(.headline)
                        }
                        .foregroundColor(.gray)
                    } else {
                        GeometryReader { geometry in
                            ScrollView {
                                LazyVGrid(columns: [
                                    GridItem(.adaptive(minimum: geometry.size.width > geometry.size.height ? 400 : 300), spacing: 20)
                                ], spacing: 20) {
                                    ForEach(viewModel.magazines) { magazine in
                                        NavigationLink(destination: MagazineReaderView(magazine: magazine)) {
                                            MagazineCoverView(magazine: magazine)
                                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                        }
                                    }
                                }
                                .padding()
                            }
                            .refreshable {
                                await viewModel.fetchMagazines()
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    PoloLifestyleHeader()
                }
            }
            .task {
                await viewModel.fetchMagazines()
            }
        }
    }
}

private struct MagazineRowView: View {
    let magazine: Magazine
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Magazine Cover Preview
            ZStack {
                AsyncImage(url: URL(string: magazine.pdf)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .tint(.gray)
                        )
                }
            }
            .frame(height: 200)
            .clipped()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(magazine.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(magazine.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.blue)
                    Text("Read Magazine")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    Spacer()
                    Text(magazine.createdAt)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
}

private struct PDFKitView: View {
    @Environment(\.presentationMode) var presentationMode
    let url: URL
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom toolbar
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding()
            .background(Color.white)
            
            // PDF View
            PDFKitRepresentedView(url)
        }
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarHidden(true)
    }
}

private struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL
    
    init(_ url: URL) {
        self.url = url
    }
    
    func makeUIView(context: UIViewRepresentableContext<PDFKitRepresentedView>) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true)
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: UIViewRepresentableContext<PDFKitRepresentedView>) {
        // No need to update
    }
} 