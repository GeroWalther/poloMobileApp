import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    @EnvironmentObject private var viewModel: MagazineViewModel
    
    var relatedArticles: [Article] {
        // Get the 3 most recent articles excluding the current one
        viewModel.articles
            .filter { $0.id != article.id }
            .prefix(3)
            .map { $0 }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero Image
                    AsyncImage(url: URL(string: article.titleImage)) { image in
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
                    .frame(width: geometry.size.width, height: 300)
                    .clipped()
                    
                    // Content Container
                    VStack(alignment: .leading, spacing: 24) {
                        // Title
                        Text(article.title)
                            .font(.custom("Times New Roman", size: 32))
                            .fontWeight(.bold)
                            .foregroundColor(.init(white: 0.2))
                            .padding(.top, 24)
                            .frame(maxWidth: geometry.size.width - 48, alignment: .leading)
                        
                        // Description
                        Text(article.description)
                            .font(.custom("Times New Roman", size: 20))
                            .foregroundColor(.init(white: 0.3))
                            .lineSpacing(8)
                            .frame(maxWidth: geometry.size.width - 48, alignment: .leading)
                        
                        // Sections
                        if let sections = article.sections {
                            ForEach(sections, id: \.subheading) { section in
                                SectionContentView(section: section, screenWidth: geometry.size.width)
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
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PoloLifestyleHeader()
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            #if DEBUG
            print("Article Detail View appeared for article: \(article.title)")
            print("Title Image URL: \(article.titleImage)")
            #endif
        }
    }
}

struct SectionContentView: View {
    let section: Article.Section
    let screenWidth: CGFloat
    @State private var selectedImage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let subheading = section.subheading {
                Text(subheading)
                    .font(.custom("Times New Roman", size: 26))
                    .fontWeight(.semibold)
                    .foregroundColor(.init(white: 0.2))
                    .frame(maxWidth: screenWidth - 48, alignment: .leading)
            }
            
            if let text = section.text {
                Text(text)
                    .font(.custom("Times New Roman", size: 18))
                    .foregroundColor(.init(white: 0.3))
                    .lineSpacing(8)
                    .frame(maxWidth: screenWidth - 48, alignment: .leading)
            }
            
            if let images = section.images, !images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(images, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
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
    }
}

// Add this extension to make String identifiable for fullScreenCover
extension String: Identifiable {
    public var id: String { self }
}

// New view for related article cards
struct RelatedArticleCard: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Image
            AsyncImage(url: URL(string: article.titleImage)) { image in
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
