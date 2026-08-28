//
//  NetworkEngine.swift
//  CocoaRestClientCore
//

import Foundation
import Security

public struct NetworkOptions: Sendable {
    public var timeoutSeconds: TimeInterval
    public var followRedirects: Bool
    public var applyHttpMethodOnRedirect: Bool
    public var allowSelfSignedCerts: Bool
    public var disableCookies: Bool
    public var environment: [String: String]

    public init(
        timeoutSeconds: TimeInterval = 30,
        followRedirects: Bool = true,
        applyHttpMethodOnRedirect: Bool = false,
        allowSelfSignedCerts: Bool = true,
        disableCookies: Bool = false,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.followRedirects = followRedirects
        self.applyHttpMethodOnRedirect = applyHttpMethodOnRedirect
        self.allowSelfSignedCerts = allowSelfSignedCerts
        self.disableCookies = disableCookies
        self.environment = environment
    }
}

public struct NetworkResponse: Identifiable, Sendable {
    public var id: UUID = UUID()
    public var statusCode: Int
    public var statusDescription: String
    public var headers: [KeyValuePair]
    public var sentHeaders: [KeyValuePair]
    public var bodyData: Data
    public var formattedBody: String
    public var latencyMs: Double
    public var contentType: String?
    public var errorDescription: String?
    public var url: URL?
    public var duration: Double

    public init(
        statusCode: Int = 0,
        statusDescription: String = "",
        headers: [KeyValuePair] = [],
        sentHeaders: [KeyValuePair] = [],
        bodyData: Data = Data(),
        formattedBody: String = "",
        latencyMs: Double = 0,
        contentType: String? = nil,
        errorDescription: String? = nil,
        url: URL? = nil,
        duration: Double = 0
    ) {
        self.statusCode = statusCode
        self.statusDescription = statusDescription
        self.headers = headers
        self.sentHeaders = sentHeaders
        self.bodyData = bodyData
        self.formattedBody = formattedBody
        self.latencyMs = latencyMs
        self.contentType = contentType
        self.errorDescription = errorDescription
        self.url = url
        self.duration = duration > 0 ? duration : (latencyMs / 1000.0)
    }

    public var isSuccess: Bool {
        statusCode >= 200 && statusCode < 300
    }

    public var bodySize: Int {
        bodyData.count
    }

    public var bodySizeString: String {
        let size = bodyData.count
        if size == 0 { return "0 B" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return String(format: "%.1f KB", Double(size) / 1024.0) }
        return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
    }

    public var isImage: Bool {
        guard let ct = contentType?.lowercased() else { return false }
        return ct.contains("image/")
    }

    public var isHtml: Bool {
        guard let ct = contentType?.lowercased() else { return false }
        return ct.contains("text/html") || ct.contains("application/xhtml")
    }

    public var isJson: Bool {
        guard let ct = contentType?.lowercased() else { return false }
        return ct.contains("json")
    }

    public var isXml: Bool {
        guard let ct = contentType?.lowercased() else { return false }
        return ct.contains("xml")
    }

    public var body: String {
        ResponseFormatter.decodePlainText(data: bodyData)
    }
}

public final class NetworkEngine: NSObject, Sendable, URLSessionTaskDelegate, URLSessionDataDelegate {
    public static let shared = NetworkEngine()

    /// Builds the URL string handed to `URL(string:)` for a request.
    ///
    /// Variables are resolved *before* the scheme fallback: a URL written as
    /// `{{baseUrl}}/get` keeps its scheme inside the variable, so prefixing first
    /// turns it into `http://https://httpbin.org/get` and the request never leaves.
    static func requestUrlString(for request: RestRequest, environment: [String: String]) -> String {
        let raw = request.url.trimmingCharacters(in: .whitespacesAndNewlines)
        var resolved = EnvironmentVariableResolver.resolve(raw, environment: environment)

        if !resolved.lowercased().hasPrefix("http://") && !resolved.lowercased().hasPrefix("https://") {
            resolved = "http://" + resolved
        }

        // If API Key is in query parameters, append to URL
        if request.auth.type == .apiKey, request.auth.apiKeyLocation == .query, !request.auth.apiKeyName.isEmpty {
            let separator = resolved.contains("?") ? "&" : "?"
            let k = request.auth.apiKeyName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? request.auth.apiKeyName
            let v = request.auth.apiKeyValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? request.auth.apiKeyValue
            resolved += "\(separator)\(k)=\(v)"
        }

        return resolved
    }

    public func execute(
        request: RestRequest,
        options: NetworkOptions = NetworkOptions()
    ) async -> NetworkResponse {
        let resolvedUrlString = Self.requestUrlString(for: request, environment: options.environment)

        guard let encodedUrlString = resolvedUrlString.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
              let url = URL(string: encodedUrlString) else {
            return NetworkResponse(
                statusCode: 0,
                statusDescription: "Invalid URL",
                errorDescription: "Unable to parse URL: \(resolvedUrlString)"
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.timeoutInterval = options.timeoutSeconds
        urlRequest.httpShouldHandleCookies = !options.disableCookies

        // Prepare Body
        let bodyResult = RequestBodyBuilder.build(for: request, environment: options.environment)
        if let bodyData = bodyResult.data {
            urlRequest.httpBody = bodyData
        }

        // Headers, auth injection and the cookie jar -- shared with the realtime
        // engines so both transports authenticate the same way.
        let builtHeaders = RequestHeaderBuilder.build(
            headers: request.headers,
            auth: request.auth,
            environment: options.environment,
            url: url,
            includeCookies: !options.disableCookies
        )
        for (k, v) in builtHeaders {
            urlRequest.setValue(v, forHTTPHeaderField: k)
        }

        // Content-Type fallback if not explicitly provided
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil, let ct = bodyResult.contentType {
            urlRequest.setValue(ct, forHTTPHeaderField: "Content-Type")
        }

        // Capture sent headers
        let sentHeaders: [KeyValuePair] = (urlRequest.allHTTPHeaderFields ?? [:]).map {
            KeyValuePair(key: $0.key, value: $0.value, isEnabled: true)
        }.sorted(by: { $0.key < $1.key })

        let delegate = CustomSessionDelegate(
            options: options,
            auth: request.auth,
            clientCertPath: request.clientCertificatePath,
            clientCertPassword: request.clientCertificatePassword
        )
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = options.timeoutSeconds
        config.timeoutIntervalForResource = options.timeoutSeconds
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let (data, response) = try await session.data(for: urlRequest)
            let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            guard let httpResponse = response as? HTTPURLResponse else {
                return NetworkResponse(
                    statusCode: 0,
                    statusDescription: "Non-HTTP Response",
                    sentHeaders: sentHeaders,
                    bodyData: data,
                    formattedBody: ResponseFormatter.format(data: data, contentType: nil),
                    latencyMs: latency,
                    url: url,
                    duration: latency / 1000.0
                )
            }

            var responseHeadersDict: [String: String] = [:]
            let responseHeaders: [KeyValuePair] = httpResponse.allHeaderFields.compactMap { (k, v) in
                guard let keyStr = k as? String, let valStr = v as? String else { return nil }
                responseHeadersDict[keyStr] = valStr
                return KeyValuePair(key: keyStr, value: valStr, isEnabled: true)
            }.sorted(by: { $0.key < $1.key })

            // Store cookies into CookieJarStore
            if !options.disableCookies {
                CookieJarStore.shared.storeCookies(from: responseHeadersDict, for: url)
            }

            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
            let formatted = ResponseFormatter.format(data: data, contentType: contentType)
            let statusText = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode).capitalized

            return NetworkResponse(
                statusCode: httpResponse.statusCode,
                statusDescription: statusText,
                headers: responseHeaders,
                sentHeaders: sentHeaders,
                bodyData: data,
                formattedBody: formatted,
                latencyMs: latency,
                contentType: contentType,
                url: httpResponse.url,
                duration: latency / 1000.0
            )
        } catch {
            let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return NetworkResponse(
                statusCode: 0,
                statusDescription: "Connection Failed",
                sentHeaders: sentHeaders,
                latencyMs: latency,
                errorDescription: error.localizedDescription,
                url: url,
                duration: latency / 1000.0
            )
        }
    }
}

private final class CustomSessionDelegate: NSObject, URLSessionTaskDelegate, URLSessionDelegate, Sendable {
    let options: NetworkOptions
    let auth: Authentication
    let clientCertPath: String
    let clientCertPassword: String

    init(options: NetworkOptions, auth: Authentication, clientCertPath: String = "", clientCertPassword: String = "") {
        self.options = options
        self.auth = auth
        self.clientCertPath = clientCertPath
        self.clientCertPassword = clientCertPassword
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard options.followRedirects else {
            completionHandler(nil)
            return
        }
        var modified = request
        if options.applyHttpMethodOnRedirect, let originalMethod = task.originalRequest?.httpMethod {
            modified.httpMethod = originalMethod
        }
        completionHandler(modified)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // 1. SSL Server Trust (Self-signed certs)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if options.allowSelfSignedCerts, let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // 2. Client Certificate (mTLS / PKCS#12)
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if !clientCertPath.isEmpty,
               let certData = try? Data(contentsOf: URL(fileURLWithPath: clientCertPath)) {
                let options: [String: Any] = [kSecImportExportPassphrase as String: clientCertPassword]
                var items: CFArray?
                let status = SecPKCS12Import(certData as CFData, options as CFDictionary, &items)
                if status == errSecSuccess, let array = items as? [[String: Any]], let first = array.first {
                    if let secIdentity = first[kSecImportItemIdentity as String] {
                        let identity = secIdentity as! SecIdentity
                        let credential = URLCredential(identity: identity, certificates: nil, persistence: .forSession)
                        completionHandler(.useCredential, credential)
                        return
                    }
                }
            }
        }

        // 3. HTTP Basic / Digest
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic ||
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest {
            if auth.hasCredentials && challenge.previousFailureCount == 0 {
                let credential = URLCredential(user: auth.username, password: auth.password, persistence: .none)
                completionHandler(.useCredential, credential)
                return
            }
        }

        completionHandler(.performDefaultHandling, nil)
    }
}
