//
//  NetworkEngine.swift
//  CocoaRestClientCore
//

import Foundation

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
        disableCookies: Bool = true,
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
        url: URL? = nil
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
    }

    public var isSuccess: Bool {
        statusCode >= 200 && statusCode < 300
    }
}

public final class NetworkEngine: NSObject, Sendable, URLSessionTaskDelegate, URLSessionDataDelegate {
    public static let shared = NetworkEngine()

    public func execute(
        request: RestRequest,
        options: NetworkOptions = NetworkOptions()
    ) async -> NetworkResponse {
        var rawUrlString = request.url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawUrlString.lowercased().hasPrefix("http://") && !rawUrlString.lowercased().hasPrefix("https://") {
            rawUrlString = "http://" + rawUrlString
        }
        let resolvedUrlString = EnvironmentVariableResolver.resolve(rawUrlString, environment: options.environment)

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

        // Set Headers
        var explicitHeaders: [String: String] = [:]
        for header in request.headers where header.isEnabled && !header.key.isEmpty {
            let k = EnvironmentVariableResolver.resolve(header.key, environment: options.environment)
            let v = EnvironmentVariableResolver.resolve(header.value, environment: options.environment)
            explicitHeaders[k] = v
            urlRequest.setValue(v, forHTTPHeaderField: k)
        }

        // Content-Type fallback if not explicitly provided
        if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil, let ct = bodyResult.contentType {
            urlRequest.setValue(ct, forHTTPHeaderField: "Content-Type")
        }

        // Authorization
        if request.auth.type == .basic, request.auth.isPreemptive, let authVal = request.auth.basicAuthHeaderValue() {
            urlRequest.setValue(authVal, forHTTPHeaderField: "Authorization")
        } else if request.auth.type == .bearer, let bearerVal = request.auth.bearerHeaderValue() {
            urlRequest.setValue(bearerVal, forHTTPHeaderField: "Authorization")
        }

        // Capture sent headers
        let sentHeaders: [KeyValuePair] = (urlRequest.allHTTPHeaderFields ?? [:]).map {
            KeyValuePair(key: $0.key, value: $0.value, isEnabled: true)
        }.sorted(by: { $0.key < $1.key })

        let delegate = CustomSessionDelegate(options: options, auth: request.auth)
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
                    url: url
                )
            }

            let responseHeaders: [KeyValuePair] = httpResponse.allHeaderFields.compactMap { (k, v) in
                guard let keyStr = k as? String, let valStr = v as? String else { return nil }
                return KeyValuePair(key: keyStr, value: valStr, isEnabled: true)
            }.sorted(by: { $0.key < $1.key })

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
                url: httpResponse.url
            )
        } catch {
            let latency = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return NetworkResponse(
                statusCode: 0,
                statusDescription: "Connection Failed",
                sentHeaders: sentHeaders,
                latencyMs: latency,
                errorDescription: error.localizedDescription,
                url: url
            )
        }
    }
}

private final class CustomSessionDelegate: NSObject, URLSessionTaskDelegate, URLSessionDelegate, Sendable {
    let options: NetworkOptions
    let auth: Authentication

    init(options: NetworkOptions, auth: Authentication) {
        self.options = options
        self.auth = auth
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
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if options.allowSelfSignedCerts, let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
            completionHandler(.performDefaultHandling, nil)
            return
        }

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
