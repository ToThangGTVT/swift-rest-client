//
//  ResponseHeadersView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore
import AppKit

public struct ResponseHeadersView: View {
    public var headers: [KeyValuePair]
    @State private var filterQuery: String = ""

    public init(headers: [KeyValuePair]) {
        self.headers = headers
    }

    private var filteredHeaders: [KeyValuePair] {
        guard !filterQuery.isEmpty else { return headers }
        return headers.filter {
            $0.key.localizedCaseInsensitiveContains(filterQuery) ||
            $0.value.localizedCaseInsensitiveContains(filterQuery)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Filter headers...", text: $filterQuery)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 240)

                Spacer()

                Button(action: copyAllHeaders) {
                    Label("Copy All", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            List(filteredHeaders) { header in
                HStack(alignment: .top) {
                    Text(header.key)
                        .fontWeight(.semibold)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 180, alignment: .leading)
                        .textSelection(.enabled)

                    Text(header.value)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)

                    Button(action: { copyHeader(header) }) {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy Header")
                }
                .padding(.vertical, 2)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private func copyHeader(_ header: KeyValuePair) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("\(header.key): \(header.value)", forType: .string)
    }

    private func copyAllHeaders() {
        let text = headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
