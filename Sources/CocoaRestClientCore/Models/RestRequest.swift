//
//  RestRequest.swift
//  CocoaRestClientCore
//

import Foundation

public enum RequestBodyType: String, Codable, CaseIterable, Sendable {
    case raw = "Raw"
    case formUrlEncoded = "Form URL Encoded"
    case multipart = "Multipart"
    case binaryFile = "Binary File"
    case graphql = "GraphQL"
}

public struct RestRequest: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var url: String
    public var method: HTTPMethod
    public var headers: [KeyValuePair]
    public var params: [KeyValuePair]
    public var urlParams: [KeyValuePair]
    public var files: [FileAttachment]
    public var auth: Authentication
    public var bodyType: RequestBodyType
    public var rawBody: String
    public var rawBodyContentType: String
    public var binaryFilePath: String
    public var graphqlQuery: String
    public var graphqlVariables: String

    // Test Assertions & Extraction Rules
    public var assertions: [TestAssertion]
    public var extractionRules: [VariableExtractionRule]

    // Client Certificate (mTLS)
    public var clientCertificatePath: String
    public var clientCertificatePassword: String

    public init(
        id: UUID = UUID(),
        name: String = "New Request",
        url: String = "https://httpbin.org/get",
        method: HTTPMethod = .get,
        headers: [KeyValuePair] = [
            KeyValuePair(key: "Content-Type", value: "application/json", isEnabled: true),
            KeyValuePair(key: "Accept", value: "*/*", isEnabled: true)
        ],
        params: [KeyValuePair] = [],
        urlParams: [KeyValuePair] = [],
        files: [FileAttachment] = [],
        auth: Authentication = Authentication(),
        bodyType: RequestBodyType = .raw,
        rawBody: String = "",
        rawBodyContentType: String = "application/json",
        binaryFilePath: String = "",
        graphqlQuery: String = "",
        graphqlVariables: String = "{}",
        assertions: [TestAssertion] = [],
        extractionRules: [VariableExtractionRule] = [],
        clientCertificatePath: String = "",
        clientCertificatePassword: String = ""
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.method = method
        self.headers = headers
        self.params = params
        self.urlParams = urlParams
        self.files = files
        self.auth = auth
        self.bodyType = bodyType
        self.rawBody = rawBody
        self.rawBodyContentType = rawBodyContentType
        self.binaryFilePath = binaryFilePath
        self.graphqlQuery = graphqlQuery
        self.graphqlVariables = graphqlVariables
        self.assertions = assertions
        self.extractionRules = extractionRules
        self.clientCertificatePath = clientCertificatePath
        self.clientCertificatePassword = clientCertificatePassword
    }

    public func duplicate(withName newName: String? = nil) -> RestRequest {
        var copy = self
        copy.id = UUID()
        if let newName = newName {
            copy.name = newName
        }
        return copy
    }

    public mutating func updateFromLegacy(
        url: String,
        method: String,
        username: String,
        password: String,
        rawRequestInput: Bool,
        requestText: String?,
        headers: [[String: String]]?,
        params: [[String: String]]?,
        files: [[String: Any]]?,
        preemptiveBasicAuth: Bool
    ) {
        self.url = url
        self.method = HTTPMethod(method)
        self.auth = Authentication(
            type: (!username.isEmpty || !password.isEmpty) ? .basic : .none,
            username: username,
            password: password,
            token: "",
            isPreemptive: preemptiveBasicAuth
        )
        self.bodyType = rawRequestInput ? .raw : .formUrlEncoded
        self.rawBody = requestText ?? ""

        if let headers = headers {
            self.headers = headers.compactMap { dict in
                let k = dict["key"] ?? dict["header-name"] ?? ""
                let v = dict["value"] ?? dict["header-value"] ?? ""
                guard !k.isEmpty else { return nil }
                return KeyValuePair(key: k, value: v, isEnabled: true)
            }
        }

        if let params = params {
            self.params = params.compactMap { dict in
                let k = dict["key"] ?? ""
                let v = dict["value"] ?? ""
                guard !k.isEmpty else { return nil }
                return KeyValuePair(key: k, value: v, isEnabled: true)
            }
        }

        if let files = files {
            self.files = files.compactMap { dict in
                let k = dict["key"] as? String ?? ""
                let urlStr: String
                if let urlObj = dict["url"] as? URL {
                    urlStr = urlObj.path
                } else if let s = dict["url"] as? String {
                    urlStr = s.replacingOccurrences(of: "file://", with: "")
                } else {
                    urlStr = ""
                }
                let gzip = dict["gzip"] as? Bool ?? false
                guard !k.isEmpty, !urlStr.isEmpty else { return nil }
                return FileAttachment(key: k, filePath: urlStr, isGzipped: gzip, isEnabled: true)
            }
            if !self.files.isEmpty && !rawRequestInput {
                self.bodyType = .multipart
            }
        }
        self.parseUrlParameters()
    }

    public mutating func parseUrlParameters() {
        guard let components = URLComponents(string: url) else { return }
        guard let queryItems = components.queryItems, !queryItems.isEmpty else { return }

        // Bail out when the table already describes this URL. Re-assigning would
        // hand every row a fresh id, churning the identity SwiftUI's ForEach keys
        // on and publishing a change for a value that did not move.
        let unchanged = urlParams.count == queryItems.count
            && zip(urlParams, queryItems).allSatisfy { pair, item in
                pair.key == item.name && pair.value == (item.value ?? "") && pair.isEnabled
            }
        guard !unchanged else { return }

        self.urlParams = queryItems.map { item in
            KeyValuePair(key: item.name, value: item.value ?? "", isEnabled: true)
        }
    }

    public mutating func rebuildUrlFromUrlParameters() {
        guard var components = URLComponents(string: url) else { return }
        let enabledItems = urlParams.filter { $0.isEnabled && !$0.key.isEmpty }
        if enabledItems.isEmpty {
            components.queryItems = nil
        } else {
            components.queryItems = enabledItems.map {
                URLQueryItem(name: $0.key, value: $0.value)
            }
        }
        if let newUrlString = components.string {
            self.url = newUrlString
        }
    }

    public func effectiveContentType() -> String? {
        if let header = headers.first(where: { $0.isEnabled && $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }) {
            return header.value
        }
        switch bodyType {
        case .formUrlEncoded:
            return "application/x-www-form-urlencoded"
        case .multipart:
            return "multipart/form-data"
        case .raw:
            return rawBodyContentType
        case .binaryFile:
            return "application/octet-stream"
        case .graphql:
            return "application/json"
        }
    }
}
