//
//  Authentication.swift
//  CocoaRestClientCore
//

import Foundation

public enum AuthType: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case basic = "Basic Auth"
    case bearer = "Bearer Token"
    case digest = "Digest Auth"
}

public struct Authentication: Codable, Hashable, Sendable {
    public var type: AuthType
    public var username: String
    public var password: String
    public var token: String
    public var isPreemptive: Bool

    public init(
        type: AuthType = .none,
        username: String = "",
        password: String = "",
        token: String = "",
        isPreemptive: Bool = true
    ) {
        self.type = type
        self.username = username
        self.password = password
        self.token = token
        self.isPreemptive = isPreemptive
    }

    public var hasCredentials: Bool {
        switch type {
        case .none:
            return false
        case .basic, .digest:
            return !username.isEmpty || !password.isEmpty
        case .bearer:
            return !token.isEmpty
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
