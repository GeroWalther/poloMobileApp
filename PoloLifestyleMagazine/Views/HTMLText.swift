import SwiftUI

/// A SwiftUI view that renders HTML content with clickable links using WKWebView
/// This component is designed to display formatted text with active hyperlinks while maintaining the app's styling
struct HTMLText: View {
    /// The HTML string to be rendered
    let html: String
    
    /// A closure that handles link interactions
    /// - Parameter URL: The URL that was tapped
    let linkHandler: (URL) -> Void
    
    var body: some View {
        if let data = html.data(using: .utf8),
           let attributedString = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil),
           let attString = try? AttributedString(attributedString) {
            
            Text(attString)
                .font(.custom("Times New Roman", size: 18))
                .foregroundColor(Color(white: 0.2, opacity: 0.8))
                .lineSpacing(8)
                .padding(.bottom, 16)
                .tint(Color(red: 0, green: 0.4, blue: 0.8))
                .environment(\.openURL, OpenURLAction { url in
                    linkHandler(url)
                    return .handled
                })
        } else {
            Text(html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                .font(.custom("Times New Roman", size: 18))
                .foregroundColor(Color(white: 0.2, opacity: 0.8))
                .lineSpacing(8)
                .padding(.bottom, 16)
                .background(Color.clear)
        }
    }
} 
            
