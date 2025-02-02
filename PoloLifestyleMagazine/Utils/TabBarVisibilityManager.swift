import SwiftUI

class TabBarVisibilityManager: ObservableObject {
    @Published var isVisible: Bool = true
    
    static let shared = TabBarVisibilityManager()
} 