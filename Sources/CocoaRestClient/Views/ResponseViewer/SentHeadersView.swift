//
//  SentHeadersView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore
import AppKit

public struct SentHeadersView: View {
    public var headers: [KeyValuePair]

    public init(headers: [KeyValuePair]) {
        self.headers = headers
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(headers.count) request header(s) transmitted")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

            if headers.isEmpty {
                VStack {
                    Text("No transmitted headers recorded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(headers) { header in
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
                    }
                    .padding(.vertical, 2)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private func copyAllHeaders() {
        let text = headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
