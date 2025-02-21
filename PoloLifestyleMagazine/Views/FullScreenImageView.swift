import SwiftUI

struct FullScreenImageView: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @EnvironmentObject private var viewModel: ArticleViewModel

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            AsyncImage(url: viewModel.fetchImageFromDocumentsDirectory(imageName: imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = value
                            }
                    )
            } placeholder: {
                ProgressView()
                    .tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .padding()
            }
        }
        .statusBar(hidden: true)
    }
} 
