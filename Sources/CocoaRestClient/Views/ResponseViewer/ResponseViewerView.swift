//
//  ResponseViewerView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore
import AppKit

public struct ResponseViewerView: View {
    @ObservedObject public var tabVM: RequestTabViewModel

    public init(tabVM: RequestTabViewModel) {
        self.tabVM = tabVM
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Status bar
            HStack {
                if let res = tabVM.response {
                    StatusBadgeView(
                        statusCode: res.statusCode,
                        statusDescription: res.statusDescription,
                        latencyMs: res.latencyMs
                    )

                    if !res.bodyData.isEmpty {
                        Text(res.bodySizeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let ct = res.contentType {
                        Text(ct)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } else if tabVM.isLoading {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Sending request...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No response yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Actions: Search, Zoom, Export, Browser
                if tabVM.response != nil {
                    HStack(spacing: 6) {
                        Button(action: {
                            tabVM.isResponseSearchPresented.toggle()
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                        .buttonStyle(.plain)
                        .help("Find in Response (Cmd+F)")

                        Button(action: { tabVM.fontSize = max(9.0, tabVM.fontSize - 1.0) }) {
                            Image(systemName: "minus.magnifyingglass")
                        }
                        .buttonStyle(.plain)
                        .help("Zoom Out")

                        Button(action: { tabVM.fontSize = min(28.0, tabVM.fontSize + 1.0) }) {
                            Image(systemName: "plus.magnifyingglass")
                        }
                        .buttonStyle(.plain)
                        .help("Zoom In")

                        Button(action: { openResponseInBrowser() }) {
                            Image(systemName: "safari")
                        }
                        .buttonStyle(.plain)
                        .help("View Response in Default Browser")

                        Button(action: { exportResponse() }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.plain)
                        .help("Export Response to File")
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Response Search Bar (if activated)
            if tabVM.isResponseSearchPresented {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Find in response...", text: $tabVM.responseSearchText)
                        .textFieldStyle(.plain)
                        .font(.caption)

                    if !tabVM.responseSearchText.isEmpty {
                        let matchesCount = countMatches(in: responseText(for: tabVM.response), query: tabVM.responseSearchText)
                        Text("\(matchesCount) matches")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Button(action: { tabVM.responseSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button("Done") {
                        tabVM.isResponseSearchPresented = false
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()
            }

            // Response Tabs (Body, Headers, Sent Headers)
            HStack {
                Picker("", selection: $tabVM.selectedResponseTab) {
                    ForEach(ResponseViewerTab.allCases) { tab in
                        if tab == .headers, let count = tabVM.response?.headers.count {
                            Text("Headers (\(count))").tag(tab)
                        } else {
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)

                Spacer()

                if tabVM.selectedResponseTab == .body && tabVM.response != nil {
                    Picker("Mode", selection: $tabVM.responseViewMode) {
                        ForEach(ResponseViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 200)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            Divider()

            // Response Content
            if let res = tabVM.response {
                if let error = res.errorDescription, res.statusCode == 0 {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.red)
                        Text("Request Failed")
                            .font(.headline)
                        Text(error)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    switch tabVM.selectedResponseTab {
                    case .body:
                        if tabVM.responseViewMode == .preview {
                            if res.isImage {
                                ImageViewerView(data: res.bodyData)
                            } else if res.isHtml {
                                HTMLPreviewView(
                                    htmlString: ResponseFormatter.decodePlainText(data: res.bodyData),
                                    baseURL: res.url
                                )
                            } else {
                                textBodyEditor(res)
                            }
                        } else {
                            textBodyEditor(res)
                        }

                    case .headers:
                        ResponseHeadersView(headers: res.headers)

                    case .sentHeaders:
                        SentHeadersView(headers: res.sentHeaders)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Submit a request to inspect response here")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func textBodyEditor(_ res: NetworkResponse) -> some View {
        let textBinding = Binding<String>(
            get: {
                if tabVM.responseViewMode == .raw {
                    return ResponseFormatter.decodePlainText(data: res.bodyData)
                }
                return res.formattedBody
            },
            set: { _ in }
        )
        SyntaxTextEditorView(
            text: textBinding,
            isEditable: false,
            fontSize: tabVM.fontSize
        )
    }

    private func responseText(for res: NetworkResponse?) -> String {
        guard let res = res else { return "" }
        if tabVM.responseViewMode == .raw {
            return ResponseFormatter.decodePlainText(data: res.bodyData)
        }
        return res.formattedBody
    }

    private func countMatches(in text: String, query: String) -> Int {
        guard !query.isEmpty else { return 0 }
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: query, options: .caseInsensitive, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<text.endIndex
        }
        return count
    }

    private func openResponseInBrowser() {
        if let tempFile = tabVM.exportResponseToTempFile() {
            NSWorkspace.shared.open(tempFile)
        }
    }

    private func exportResponse() {
        guard let res = tabVM.response, !res.bodyData.isEmpty else { return }
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        let ext = res.contentType?.contains("json") == true ? "json" : (res.contentType?.contains("xml") == true ? "xml" : (res.isHtml ? "html" : "txt"))
        panel.nameFieldStringValue = "response.\(ext)"
        if panel.runModal() == .OK, let url = panel.url {
            try? res.bodyData.write(to: url)
        }
    }
}
