//
//  HTMLPreviewView.swift
//  CocoaRestClient
//

import SwiftUI
import WebKit

public struct HTMLPreviewView: NSViewRepresentable {
    public let htmlString: String
    public let baseURL: URL?

    public init(htmlString: String, baseURL: URL? = nil) {
        self.htmlString = htmlString
        self.baseURL = baseURL
    }

    public func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(htmlString, baseURL: baseURL)
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlString, baseURL: baseURL)
    }
}
