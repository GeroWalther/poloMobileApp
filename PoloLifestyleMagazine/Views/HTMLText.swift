import SwiftUI
import WebKit

/// A SwiftUI view that renders HTML content with clickable links using WKWebView
/// This component is designed to display formatted text with active hyperlinks while maintaining the app's styling
struct HTMLText: UIViewRepresentable {
    /// The HTML string to be rendered
    let html: String
    
    /// A closure that handles link interactions
    /// - Parameter URL: The URL that was tapped
    let linkHandler: (URL) -> Void
    
    /// Creates and configures a WKWebView instance to display the HTML content
    /// - Parameter context: The context in which the view is being created
    /// - Returns: A configured WKWebView instance
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        
        // Inject CSS for styling
        let css = """
            body {
                font-family: 'Times New Roman';
                font-size: 18px;
                color: rgba(51, 51, 51, 0.8);
                line-height: 1.5;
                margin: 0;
                padding: 0;
                background-color: transparent;
            }
            a {
                color: #0066cc;
                text-decoration: underline;
            }
        """
        
        let wrappedHTML = """
            <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <style>\(css)</style>
                </head>
                <body>
                    \(html)
                </body>
            </html>
        """
        
        webView.loadHTMLString(wrappedHTML, baseURL: nil)
        return webView
    }
    
    /// Updates the view when SwiftUI updates the state
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    
    /// Creates a coordinator to handle the WKWebView's navigation delegate
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Coordinator class that handles WKWebView navigation delegate callbacks
    class Coordinator: NSObject, WKNavigationDelegate {
        /// Reference to the parent HTMLText view
        var parent: HTMLText
        
        init(_ parent: HTMLText) {
            self.parent = parent
        }
        
        /// Handles navigation actions in the WKWebView
        /// - Parameters:
        ///   - webView: The web view requesting the policy decision
        ///   - navigationAction: The navigation action that triggered this callback
        ///   - decisionHandler: A closure to call with the policy decision
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                parent.linkHandler(url)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
} 