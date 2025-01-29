import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
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
                .frame(height: 300)
                .clipped()
                
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(article.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                    
                    // Date
                    Text(article.publishDate, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.black.opacity(0.6))
                    
                    // Description
                    Text(article.description)
                        .font(.body)
                        .foregroundColor(.black)
                        .lineSpacing(6)
                    
                    // Additional Images
                    if let images = article.images {
                        ForEach(images, id: \.self) { imageUrl in
                            AsyncImage(url: URL(string: imageUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .aspectRatio(16/9, contentMode: .fit)
                                    .overlay(
                                        ProgressView()
                                            .tint(.gray)
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                PoloLifestyleHeader()
            }
        }
        .onAppear {
            #if DEBUG
            print("Article Detail View appeared for article: \(article.title)")
            print("Title Image URL: \(article.titleImage)")
            print("Number of additional images: \(String(describing: article.images?.count))")
            #endif
        }
    }
} 
