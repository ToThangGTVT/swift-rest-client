//
//  ResponseViewerView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore
import AppKit

public struct ResponseViewerView: View {
    @ObservedObject public var tabVM: RequestTabViewModel

    @State private var isTabRowCompact: Bool = false

    public init(tabVM: RequestTabViewModel) {
        self.tabVM = tabVM
    }

    /// Width this row needs to show the segmented tab picker at full size next to
    /// the Pretty/Raw/Preview picker.
    private var tabRowThreshold: CGFloat {
        var needed: CGFloat = 440 + 24 // picker + horizontal padding
        if tabVM.selectedResponseTab == .body && tabVM.response != nil {
            needed += 12 + 200 // spacing + Pretty/Raw/Preview picker
        }
        return needed
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
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Find in response...", text: $tabVM.responseSearchText)
                        .textFieldStyle(.plain)

                    if !tabVM.responseSearchText.isEmpty {
                        let count = tabVM.responseSearchMatchCount
                        Text("\(count) match\(count == 1 ? "" : "es")")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button(action: { tabVM.responseSearchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button("Done") {
                        tabVM.isResponseSearchPresented = false
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()
            }

            // Response Tabs (Body, Headers, Sent Headers, Cookies, Tests)
            HStack(spacing: 12) {
                if isTabRowCompact {
                    CompactOptionMenu(
                        options: ResponseViewerTab.allCases,
                        title: { responseTabTitle($0) },
                        selection: $tabVM.selectedResponseTab
                    )
                } else {
                    Picker("", selection: $tabVM.selectedResponseTab) {
                        ForEach(ResponseViewerTab.allCases) { tab in
                            Text(responseTabTitle(tab)).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 440)
                }

                Spacer()

                if tabVM.selectedResponseTab == .body && tabVM.response != nil {
                    Picker("", selection: $tabVM.responseViewMode) {
                        ForEach(ResponseViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .widthBreakpoint(tabRowThreshold, isCompact: $isTabRowCompact)

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
                                    htmlString: tabVM.rawResponseText,
                                    baseURL: res.url
                                )
                            } else {
                                textBodyEditor()
                            }
                        } else {
                            textBodyEditor()
                        }

                    case .headers:
                        ResponseHeadersView(headers: res.headers)

                    case .sentHeaders:
                        SentHeadersView(headers: res.sentHeaders)

                    case .cookies:
                        cookiesView(for: res)

                    case .tests:
                        testsResultsView
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

    private func responseTabTitle(_ tab: ResponseViewerTab) -> String {
        switch tab {
        case .body:
            return "Body"
        case .headers:
            let count = tabVM.response?.headers.count ?? 0
            return count > 0 ? "Headers (\(count))" : "Headers"
        case .sentHeaders:
            return "Sent Headers"
        case .cookies:
            if let url = tabVM.response?.url {
                let count = CookieJarStore.shared.cookies(for: url).count
                return count > 0 ? "Cookies (\(count))" : "Cookies"
            }
            return "Cookies"
        case .tests:
            if !tabVM.testResults.isEmpty {
                let passed = tabVM.testResults.filter { $0.passed }.count
                return "Tests (\(passed)/\(tabVM.testResults.count))"
            }
            return "Tests"
        }
    }

    @ViewBuilder
    private func cookiesView(for res: NetworkResponse) -> some View {
        let cookies = res.url != nil ? CookieJarStore.shared.cookies(for: res.url!) : []
        if cookies.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "circle.hexagongrid")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
                Text("No cookies associated with this request/response")
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(cookies) { cookie in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cookie.name)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                            Text(cookie.value)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(cookie.domain)
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                            Text(cookie.path)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    private var testsResultsView: some View {
        Group {
            if tabVM.testResults.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No tests executed")
                        .foregroundColor(.secondary)
                    Text("Configure test assertions in the Request Editor > Tests tab")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(tabVM.testResults) { result in
                        HStack(spacing: 10) {
                            Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.passed ? .green : .red)
                                .font(.system(size: 16))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.assertion.type.rawValue)
                                    .fontWeight(.semibold)
                                    .font(.subheadline)
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(result.passed ? "PASS" : "FAIL")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(result.passed ? Color.green.opacity(0.18) : Color.red.opacity(0.18))
                                .foregroundColor(result.passed ? .green : .red)
                                .cornerRadius(4)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    @ViewBuilder
    private func textBodyEditor() -> some View {
        let tabVM = tabVM
        let textBinding = Binding<String>(
            get: { tabVM.displayedResponseText },
            set: { _ in }
        )
        SyntaxTextEditorView(
            text: textBinding,
            isEditable: false,
            fontSize: tabVM.fontSize
        )
    }

    private func openResponseInBrowser() {
        guard let res = tabVM.response, !res.bodyData.isEmpty else { return }
        let tempUrl = FileManager.default.temporaryDirectory.appendingPathComponent("response.html")
        try? res.bodyData.write(to: tempUrl)
        NSWorkspace.shared.open(tempUrl)
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
