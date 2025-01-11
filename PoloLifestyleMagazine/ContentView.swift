//
//  ContentView.swift
//  PoloLifestyleMagazine
//
//  Created by Gero Walther on 11/1/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: MagazineViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient with grey tones
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)), // Light grey
                        Color(UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0))  // Slightly darker grey
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                Group {
                    if viewModel.isLoading {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.gray)
                            Text("Loading Magazines...")
                                .foregroundColor(.gray)
                                .font(.headline)
                        }
                    } else if let error = viewModel.error {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 50))
                            Text("Failed to load magazines")
                                .font(.headline)
                            Text(error.localizedDescription)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                            Button("Try Again") {
                                Task {
                                    await viewModel.fetchMagazines()
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.gray)
                        }
                        .foregroundColor(.gray)
                    } else if viewModel.magazines.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "magazine")
                                .font(.system(size: 50))
                            Text("No magazines available")
                                .font(.headline)
                        }
                        .foregroundColor(.gray)
                    } else {
                        MagazineGridView(
                            magazines: viewModel.magazines,
                            onRefresh: { await viewModel.fetchMagazines() }
                        )
                    }
                }
            }
            .navigationTitle("POLO&Lifestyle")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(
                Color(UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            await viewModel.fetchMagazines()
        }
    }
}

struct MagazineGridView: View {
    let magazines: [Magazine]
    let onRefresh: () async -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: geometry.size.width > geometry.size.height ? 400 : 300), spacing: 20)
                ], spacing: 20) {
                    ForEach(magazines) { magazine in
                        NavigationLink(destination: MagazineReaderView(magazine: magazine)) {
                            MagazineCoverView(magazine: magazine)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                await onRefresh()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MagazineViewModel())
}
