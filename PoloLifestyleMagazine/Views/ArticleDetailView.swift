import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title Image
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
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 12) {
                    // Title
                    Text(article.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    // Date
                    Text(article.publishDate, style: .date)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Description
                    Text(article.description)
                        .font(.body)
                        .padding(.vertical)
                    
                    // Additional Images
                    ForEach(article.images ?? [], id: \.self) { imageUrl in
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
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
        }
        .background(Color(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            #if DEBUG
            print("Article Detail View appeared for article: \(article.title)")
            print("Title Image URL: \(article.titleImage)")
            print("Number of additional images: \(String(describing: article.images?.count))")
            #endif
        }
    }
} 
