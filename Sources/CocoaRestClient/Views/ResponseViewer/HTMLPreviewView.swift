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

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.loadHTMLString(htmlString, baseURL: baseURL)
        context.coordinator.loadedHTML = htmlString
        context.coordinator.loadedBaseURL = baseURL
        return webView
    }

    public func updateNSView(_ nsView: WKWebView, context: Context) {
        // Reload only when the content actually changed. updateNSView runs on every
        // layout pass, so reloading unconditionally re-parses and re-renders the whole
        // document on each step of a window resize.
        guard context.coordinator.loadedHTML != htmlString
                || context.coordinator.loadedBaseURL != baseURL else { return }
        context.coordinator.loadedHTML = htmlString
        context.coordinator.loadedBaseURL = baseURL
        nsView.loadHTMLString(htmlString, baseURL: baseURL)
    }

    public final class Coordinator {
        var loadedHTML: String?
        var loadedBaseURL: URL?
    }
}
