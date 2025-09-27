import SwiftUI

struct LazyImageView: View {
    let article: Article
    let height: CGFloat
    @EnvironmentObject private var viewModel: ArticleViewModel
    @State private var shouldLoad = false
    
    private var imageFileName: String {
        // Always use article ID as filename for consistency
        return "\(article.id).jpg"
    }
    
    var body: some View {
        let imageURL = shouldLoad ? viewModel.fetchImageFromDocumentsDirectory(imageName: imageFileName) : nil
        
        Group {
            if shouldLoad, let url = imageURL {
                // Try UIImage approach first for debugging
                if let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    // Fallback to AsyncImage
                    AsyncImage(url: url) { image in
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
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.title2)
                            if shouldLoad {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.gray)
                            }
                        }
                    )
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)  // Ensure proper width constraint
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Only start loading when the view appears
            shouldLoad = true
        }
    }
}

