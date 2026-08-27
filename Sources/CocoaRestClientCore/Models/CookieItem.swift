//
//  CookieItem.swift
//  CocoaRestClientCore
//

import Foundation

public struct CookieItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var value: String
    public var domain: String
    public var path: String
    public var expires: Date?
    public var isSecure: Bool
    public var isHttpOnly: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        value: String,
        domain: String,
        path: String = "/",
        expires: Date? = nil,
        isSecure: Bool = false,
        isHttpOnly: Bool = false
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expires = expires
        self.isSecure = isSecure
        self.isHttpOnly = isHttpOnly
    }

    public var isExpired: Bool {
        guard let expires = expires else { return false }
        return expires < Date()
    }
}
