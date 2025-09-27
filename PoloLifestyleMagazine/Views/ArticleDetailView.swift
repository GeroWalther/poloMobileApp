import SwiftUI
import SafariServices

/// A view that displays the content of a single article with rich text formatting and clickable links
struct ArticleDetailView: View {
    let article: Article
    @EnvironmentObject private var viewModel: ArticleViewModel
    
    var relatedArticles: [Article] {
        viewModel.articles
            .filter { $0.id != article.id }
            .prefix(3)
            .map { $0 }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                AsyncImage(url: viewModel.fetchImageFromDocumentsDirectory(imageName: article.titleImage)) { image in
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
                .frame(maxWidth: .infinity, minHeight: 300, maxHeight: 300)
                .padding(.top, 95)
                .clipped()
                .onAppear {
                    // Download image if needed when detail view appears
                    Task {
                        await viewModel.downloadImageIfNeeded(for: article)
                    }
                }
                
                // Content Container
                VStack(alignment: .leading, spacing: 24) {
                    // Title and Description
                    articleHeader()
                    
                    // Sections
                    if let sections = article.sections {
                        ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                            SectionContentView(section: section, screenWidth: nil)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                
                // You May Also Like section
                if !relatedArticles.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("You May Also Like")
                            .font(.custom("Times New Roman", size: 24))
                            .fontWeight(.bold)
                            .foregroundColor(.init(white: 0.2))
                            .padding(.horizontal, 24)
                            .padding(.top, 32)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(relatedArticles) { relatedArticle in
                                    NavigationLink {
                                        ArticleDetailView(article: relatedArticle)
                                    } label: {
                                        RelatedArticleCard(article: relatedArticle)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PoloLifestyleHeader()
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }
    
    private func articleHeader() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.custom("Times New Roman", size: 32))
                .fontWeight(.bold)
                .foregroundColor(.init(white: 0.2))
                .padding(.top, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(article.description)
                .font(.custom("Times New Roman", size: 20))
                .foregroundColor(.init(white: 0.3))
                .lineSpacing(8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A view that displays the content of a single article with rich text formatting and clickable links
struct SectionContentView: View {
    let section: Article.Section
    let screenWidth: CGFloat?
    /// Tracks the currently selected image for full-screen display
    @State private var selectedImage: String?
    /// Tracks the URL that should be displayed in the Safari view
    @State private var presentedURL: URL?
    @EnvironmentObject private var viewModel: ArticleViewModel
    
    private func downloadSectionImageIfNeeded(imageUrl: String) async {
        // Check if this is already a local filename or needs to be downloaded
        let imagePath = viewModel.fetchImageFromDocumentsDirectory(imageName: imageUrl)
        
        // If file doesn't exist locally and imageUrl looks like a URL, download it
        if imagePath != nil && !FileManager.default.fileExists(atPath: imagePath!.path) && imageUrl.contains("http") {
            do {
                if let url = URL(string: imageUrl) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    let fileName = URL(string: imageUrl)?.lastPathComponent ?? UUID().uuidString + ".jpg"
                    
                    let fileManager = FileManager.default
                    guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        return
                    }
                    
                    let fileURL = documentsDirectory.appendingPathComponent(fileName)
                    try data.write(to: fileURL)
                }
            } catch {
                // Silently handle section image download failures
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let subheading = section.subheading, !subheading.isEmpty {
                Text(subheading)
                    .font(.custom("Times New Roman", size: 24))
                    .fontWeight(.semibold)
                    .foregroundColor(.init(white: 0.2))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let text = section.text, !text.isEmpty {
                HTMLText(html: text) { url in
                    presentedURL = url
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            if let images = section.images, !images.isEmpty {
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(images, id: \.self) { imageUrl in
                            let imageFileURL = viewModel.fetchImageFromDocumentsDirectory(imageName: imageUrl)
                            
                            AsyncImage(url: imageFileURL) { image in
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
                            .frame(width: 280, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onTapGesture {
                                selectedImage = imageUrl
                            }
                            .onAppear {
                                // Download section image if needed
                                Task {
                                    await downloadSectionImageIfNeeded(imageUrl: imageUrl)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.leading, 24)
                }
                .padding(.horizontal, -24)
            }
        }
        .fullScreenCover(item: $selectedImage) { imageUrl in
            FullScreenImageView(imageUrl: imageUrl)
        }
        .sheet(item: $presentedURL) { url in
            SafariView(url: url)
        }
    }
}

/// A view controller representative that wraps SFSafariViewController for displaying web content
struct SafariView: UIViewControllerRepresentable {
    /// The URL to display in the Safari view
    let url: URL
    
    /// Creates and configures an SFSafariViewController instance
    /// - Parameter context: The context in which the view controller is being created
    /// - Returns: A configured SFSafariViewController instance
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safariViewController = SFSafariViewController(url: url, configuration: config)
        return safariViewController
    }
    
    /// Updates the view controller when SwiftUI updates the state
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// Extension to make String conform to Identifiable for use with fullScreenCover
extension String: Identifiable {
    public var id: String { self }
}

/// Extension to make URL conform to Identifiable for use with SwiftUI sheets
extension URL: Identifiable {
    public var id: String { absoluteString }
}

/// A view that displays a card for a related article in the "You May Also Like" section
struct RelatedArticleCard: View {
    let article: Article
    @EnvironmentObject private var viewModel: ArticleViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            AsyncImage(url: viewModel.fetchImageFromDocumentsDirectory(imageName: article.titleImage)) { image in
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
            .frame(width: 280, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onAppear {
                // Download image if needed when related article appears
                Task {
                    await viewModel.downloadImageIfNeeded(for: article)
                }
            }
            
            // Text content
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.custom("Times New Roman", size: 16))
                    .fontWeight(.medium)
                    .foregroundColor(.init(white: 0.2))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 44) // Fixed height for 2 lines of title
                
                Text(article.description)
                    .font(.custom("Times New Roman", size: 14))
                    .foregroundColor(.init(white: 0.3))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 36) // Fixed height for 2 lines of description
                
                Text(article.publishDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.custom("Times New Roman", size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280, height: 280) // Fixed total height
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 
