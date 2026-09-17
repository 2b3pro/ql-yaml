import SwiftUI
import WebKit

public struct YAMLWebView: NSViewRepresentable {
    public let htmlString: String
    
    public init(htmlString: String) {
        self.htmlString = htmlString
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground") // Transparent native background
        return webView
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlString, baseURL: nil)
    }
}
