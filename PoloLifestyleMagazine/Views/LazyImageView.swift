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
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                            .font(.title2)
                    )
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            // Only start loading when the view appears
            shouldLoad = true
        }
        .onDisappear {
            // Optional: You can implement unloading logic here if needed
        }
    }
}

// Alternative implementation using visibility detection
struct LazyImageViewWithVisibility: View {
    let imageUrl: String
    let height: CGFloat
    @EnvironmentObject private var viewModel: ArticleViewModel
    @State private var isVisible = false
    @State private var shouldLoad = false
    
    var body: some View {
        AsyncImage(url: shouldLoad ? viewModel.fetchImageFromDocumentsDirectory(imageName: imageUrl) : nil) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Group {
                        if shouldLoad {
                            ProgressView()
                                .tint(.gray)
                        } else {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.title2)
                        }
                    }
                )
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(
            // Invisible geometry reader to detect when view is visible
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        // Check if the view is actually visible on screen
                        isVisible = true
                        if isVisible && !shouldLoad {
                            // Add a small delay to avoid loading too many images at once
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                shouldLoad = true
                            }
                        }
                    }
                    .onDisappear {
                        isVisible = false
                    }
            }
        )
    }
}