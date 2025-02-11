struct CachedAsyncImage<Content: View>: View {
    private let url: URL
    private let scale: CGFloat
    private let transaction: Transaction
    private let content: (AsyncImagePhase) -> Content
    
    init(
        url: URL,
        scale: CGFloat = 1.0,
        transaction: Transaction = Transaction(),
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.transaction = transaction
        self.content = content
    }
    
    var body: some View {
        AsyncImage(
            url: url,
            scale: scale,
            transaction: transaction,
            content: { phase in
                if case .success(let image) = phase {
                    Task {
                        await ImageCache.shared.insert(image, for: url)
                    }
                }
                content(phase)
            }
        )
        .task {
            if let cached = await ImageCache.shared.image(for: url) {
                content(.success(cached))
            }
        }
    }
} 