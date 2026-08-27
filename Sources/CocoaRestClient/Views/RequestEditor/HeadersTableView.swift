//
//  HeadersTableView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct HeadersTableView: View {
    @Binding public var headers: [KeyValuePair]

    public init(headers: Binding<[KeyValuePair]>) {
        self._headers = headers
    }

    private let commonHeaders = [
        "Accept",
        "Accept-Encoding",
        "Accept-Language",
        "Authorization",
        "Cache-Control",
        "Content-Type",
        "Cookie",
        "Origin",
        "Referer",
        "User-Agent",
        "X-Requested-With",
        "X-API-Key"
    ]

    public var body: some View {
        VStack(spacing: 8) {
            KeyValueEditorTable(
                items: $headers,
                keyPlaceholder: "Header Name (e.g. Authorization)",
                valuePlaceholder: "Header Value (e.g. Bearer token)",
                commonKeys: commonHeaders
            )
        }
    }
}
