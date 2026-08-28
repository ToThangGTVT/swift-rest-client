//
//  RequestHeaderBuilder.swift
//  CocoaRestClientCore
//

import Foundation

/// Builds the outgoing header set for a request: the user's own headers, the
/// injection for the selected auth scheme, and the cookie jar.
///
/// Shared by `NetworkEngine` and the realtime engines so an HTTP request and a
/// WebSocket/SSE stream against the same API authenticate identically.
public enum RequestHeaderBuilder {
    public static func build(
        headers: [KeyValuePair],
        auth: Authentication = Authentication(),
        environment: [String: String] = [:],
        url: URL? = nil,
        includeCookies: Bool = true
    ) -> [String: String] {
        var result: [String: String] = [:]

        for header in headers where header.isEnabled && !header.key.isEmpty {
            let key = EnvironmentVariableResolver.resolve(header.key, environment: environment)
            let value = EnvironmentVariableResolver.resolve(header.value, environment: environment)
            result[key] = value
        }

        // Auth deliberately wins over a hand-written Authorization header.
        let auth = resolving(auth, environment: environment)
        switch auth.type {
        case .basic:
            if auth.isPreemptive, let value = auth.basicAuthHeaderValue() {
                result["Authorization"] = value
            }
        case .bearer:
            if let value = auth.bearerHeaderValue() {
                result["Authorization"] = value
            }
        case .apiKey:
            if auth.apiKeyLocation == .header, !auth.apiKeyName.isEmpty {
                result[auth.apiKeyName] = auth.apiKeyValue
            }
        case .oauth2:
            if !auth.oauth2AccessToken.isEmpty {
                result["Authorization"] = "Bearer \(auth.oauth2AccessToken)"
            }
        case .none, .digest:
            break
        }

        if includeCookies, let url, let cookieHeader = CookieJarStore.shared.cookieHeaderValue(for: url) {
            result["Cookie"] = result["Cookie"].map { "\($0); \(cookieHeader)" } ?? cookieHeader
        }

        return result
    }

    /// Credential fields accept `{{var}}` the same way headers do -- otherwise a
    /// token kept in an environment has to be pasted into every request by hand.
    private static func resolving(_ auth: Authentication, environment: [String: String]) -> Authentication {
        guard !environment.isEmpty else { return auth }
        func r(_ value: String) -> String {
            EnvironmentVariableResolver.resolve(value, environment: environment)
        }
        var copy = auth
        copy.username = r(auth.username)
        copy.password = r(auth.password)
        copy.token = r(auth.token)
        copy.apiKeyName = r(auth.apiKeyName)
        copy.apiKeyValue = r(auth.apiKeyValue)
        copy.oauth2AccessToken = r(auth.oauth2AccessToken)
        return copy
    }
}
