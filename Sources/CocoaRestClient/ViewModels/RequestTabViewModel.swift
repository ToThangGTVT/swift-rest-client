//
//  RequestTabViewModel.swift
//  CocoaRestClient
//

import Foundation
import SwiftUI
import CocoaRestClientCore
import AppKit

public enum RequestEditorTab: String, CaseIterable, Identifiable {
    case body = "Body"
    case params = "Query Params"
    case headers = "Headers"
    case auth = "Auth"
    case formFields = "Form Data"
    case files = "Files"

    public var id: String { rawValue }
}

public enum ResponseViewerTab: String, CaseIterable, Identifiable {
    case body = "Body"
    case headers = "Headers"
    case sentHeaders = "Sent Headers"

    public var id: String { rawValue }
}

public enum ResponseViewMode: String, CaseIterable, Identifiable {
    case pretty = "Pretty"
    case raw = "Raw"
    case preview = "Preview"

    public var id: String { rawValue }
}

public final class RequestTabViewModel: ObservableObject, Identifiable {
    public let id: UUID
    @Published public var request: RestRequest
    @Published public var response: NetworkResponse?
    @Published public var isLoading: Bool = false
    @Published public var selectedRequestTab: RequestEditorTab = .body
    @Published public var selectedResponseTab: ResponseViewerTab = .body
    @Published public var responseViewMode: ResponseViewMode = .pretty
    @Published public var fontSize: CGFloat = 13.0
    
    // Response Search
    @Published public var isResponseSearchPresented: Bool = false
    @Published public var responseSearchText: String = ""

    private var lastExecutedRequest: RestRequest?

    public init(id: UUID = UUID(), request: RestRequest = RestRequest()) {
        self.id = id
        self.request = request
    }

    public var tabTitle: String {
        if !request.name.isEmpty && request.name != "New Request" {
            return request.name
        }
        if let host = URL(string: request.url)?.host, !host.isEmpty {
            return "\(request.method.rawValue) \(host)"
        }
        return "Untitled Request"
    }

    @MainActor
    public func sendRequest(options: NetworkOptions? = nil) {
        guard !isLoading else { return }
        isLoading = true
        lastExecutedRequest = request

        var netOptions = options ?? PreferencesViewModel.shared.networkOptions
        netOptions.environment = EnvironmentViewModel.shared.activeVariables

        Task {
            let res = await NetworkEngine.shared.execute(request: request, options: netOptions)
            await MainActor.run {
                self.response = res
                self.isLoading = false

                // Record into History
                HistoryStore.shared.addEntry(
                    request: self.request,
                    statusCode: res.statusCode,
                    latencyMs: res.latencyMs,
                    responseSize: res.bodySize
                )
                HistoryViewModel.shared.refresh()
            }
        }
    }

    @MainActor
    public func reloadLastRequest(options: NetworkOptions? = nil) {
        if let last = lastExecutedRequest {
            self.request = last
        }
        sendRequest(options: options)
    }

    public func copyCurlCommand() {
        let env = EnvironmentViewModel.shared.activeVariables
        let curl = CurlCommandGenerator.generate(from: request, environment: env)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(curl, forType: .string)
    }

    public func generateCode(language: CodeLanguage) -> String {
        let env = EnvironmentViewModel.shared.activeVariables
        return CodeGenerator.generate(language: language, request: request, environment: env)
    }

    public func formatRawBody() {
        guard !request.rawBody.isEmpty else { return }
        if let data = request.rawBody.data(using: .utf8),
           let formatted = ResponseFormatter.formatJson(data: data) {
            request.rawBody = formatted
        }
    }

    public func exportResponseToTempFile() -> URL? {
        guard let res = response, !res.bodyData.isEmpty else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let ext = res.contentType?.contains("json") == true ? "json" : (res.contentType?.contains("xml") == true ? "xml" : (res.isHtml ? "html" : "txt"))
        let fileUrl = tempDir.appendingPathComponent("response-\(Date().timeIntervalSince1970).\(ext)")
        try? res.bodyData.write(to: fileUrl)
        return fileUrl
    }
}
