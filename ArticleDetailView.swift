import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title Image
                AsyncImage(url: URL(string: article.titleImage)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(height: 200)
                .clipped()
                
                VStack(alignment: .leading, spacing: 12) {
                    // Title and Description
                    Text(article.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(article.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Sections
                    if let sections = article.sections {
                        ForEach(sections, id: \.subheading) { section in
                            SectionView(section: section)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

struct SectionView: View {
    let section: Article.Section
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let subheading = section.subheading {
                Text(subheading)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            if let text = section.text {
                Text(text)
                    .font(.body)
            }
            
            if let images = section.images {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(images, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 200, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    ArticleDetailView(article: Article(
        id: UUID(),
        createdAt: Date(),
        title: "Sample Article",
        description: "This is a sample article description",
        titleImage: "https://example.com/image.jpg",
        sections: [
            Article.Section(
                subheading: "First Section",
                text: "This is the content of the first section.",
                images: ["https://example.com/image1.jpg"]
            )
        ]
    ))
} 