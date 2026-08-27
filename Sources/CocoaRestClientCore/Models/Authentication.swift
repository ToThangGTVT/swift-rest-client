//
//  Authentication.swift
//  CocoaRestClientCore
//

import Foundation

public enum AuthType: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case basic = "Basic Auth"
    case bearer = "Bearer Token"
    case apiKey = "API Key"
    case oauth2 = "OAuth 2.0"
    case digest = "Digest Auth"
}

public enum APIKeyLocation: String, Codable, CaseIterable, Sendable {
    case header = "Header"
    case query = "Query Params"
}

public enum OAuth2GrantType: String, Codable, CaseIterable, Sendable {
    case clientCredentials = "Client Credentials"
    case password = "Password Credentials"
    case authorizationCode = "Authorization Code"
}

public struct Authentication: Codable, Hashable, Sendable {
    public var type: AuthType
    public var username: String
    public var password: String
    public var token: String
    public var isPreemptive: Bool

    // API Key fields
    public var apiKeyName: String
    public var apiKeyValue: String
    public var apiKeyLocation: APIKeyLocation

    // OAuth 2.0 fields
    public var oauth2GrantType: OAuth2GrantType
    public var oauth2AuthUrl: String
    public var oauth2TokenUrl: String
    public var oauth2ClientId: String
    public var oauth2ClientSecret: String
    public var oauth2Scope: String
    public var oauth2AccessToken: String

    public init(
        type: AuthType = .none,
        username: String = "",
        password: String = "",
        token: String = "",
        isPreemptive: Bool = true,
        apiKeyName: String = "X-API-Key",
        apiKeyValue: String = "",
        apiKeyLocation: APIKeyLocation = .header,
        oauth2GrantType: OAuth2GrantType = .clientCredentials,
        oauth2AuthUrl: String = "",
        oauth2TokenUrl: String = "",
        oauth2ClientId: String = "",
        oauth2ClientSecret: String = "",
        oauth2Scope: String = "",
        oauth2AccessToken: String = ""
    ) {
        self.type = type
        self.username = username
        self.password = password
        self.token = token
        self.isPreemptive = isPreemptive
        self.apiKeyName = apiKeyName
        self.apiKeyValue = apiKeyValue
        self.apiKeyLocation = apiKeyLocation
        self.oauth2GrantType = oauth2GrantType
        self.oauth2AuthUrl = oauth2AuthUrl
        self.oauth2TokenUrl = oauth2TokenUrl
        self.oauth2ClientId = oauth2ClientId
        self.oauth2ClientSecret = oauth2ClientSecret
        self.oauth2Scope = oauth2Scope
        self.oauth2AccessToken = oauth2AccessToken
    }

    public var hasCredentials: Bool {
        switch type {
        case .none:
            return false
        case .basic, .digest:
            return !username.isEmpty || !password.isEmpty
        case .bearer:
            return !token.isEmpty
        case .apiKey:
            return !apiKeyName.isEmpty && !apiKeyValue.isEmpty
        case .oauth2:
            return !oauth2AccessToken.isEmpty || (!oauth2TokenUrl.isEmpty && !oauth2ClientId.isEmpty)
        }
    }

    public func basicAuthHeaderValue() -> String? {
        guard type == .basic, hasCredentials else { return nil }
        let combined = "\(username):\(password)"
        guard let data = combined.data(using: .utf8) else { return nil }
        return "Basic \(data.base64EncodedString())"
    }

    public func bearerHeaderValue() -> String? {
        guard type == .bearer, !token.isEmpty else { return nil }
        return "Bearer \(token)"
    }
}
