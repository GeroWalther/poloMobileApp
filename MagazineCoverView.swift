struct MagazineCoverView: View {
    let magazine: Magazine
    @State private var isLoadingThumbnail = true
    @State private var loadError: Error?
    @EnvironmentObject private var viewModel: MagazineViewModel
} 