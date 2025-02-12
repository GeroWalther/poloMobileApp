import SwiftUI
import PDFKit

struct MagazineCoverView: View {
    let magazine: Magazine
    @State private var isLoadingThumbnail = true
    @State private var loadError: Error?
    @StateObject private var viewModel = MagazineViewModel()

    var body: some View {
        VStack(alignment: .leading) {
            if let url = viewModel.fetchMagazineFromDocuments(fileName: magazine.pdf) {
                ZStack {
                    PDFThumbnailView(url: url, isLoading: $isLoadingThumbnail, error: $loadError)
                        .frame(height: 400)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                    
                    if isLoadingThumbnail {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                    }
                    
                    if loadError != nil {
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                            Text("Failed to load preview")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.8))
                    }
                }
                .overlay(
                    VStack(alignment: .leading) {
                        Spacer()
                        VStack(alignment: .leading, spacing: 8) {
                            Text(magazine.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text(magazine.description)
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                    }
                )
                .shadow(radius: 10)
            }
        }
    }
} 

