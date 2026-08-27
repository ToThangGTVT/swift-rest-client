//
//  CommonHeaders.swift
//  CocoaRestClientCore
//

import Foundation

public struct CommonHeaders: Sendable {
    public static let standardHeaderKeys: [String] = [
        "Accept",
        "Accept-Charset",
        "Accept-Encoding",
        "Accept-Language",
        "Authorization",
        "Cache-Control",
        "Connection",
        "Content-Disposition",
        "Content-Encoding",
        "Content-Length",
        "Content-Type",
        "Cookie",
        "Host",
        "If-Match",
        "If-Modified-Since",
        "If-None-Match",
        "Origin",
        "Pragma",
        "Range",
        "Referer",
        "User-Agent",
        "X-API-Key",
        "X-CSRF-Token",
        "X-Forwarded-For",
        "X-Forwarded-Proto",
        "X-Request-ID",
        "X-Requested-With"
    ]

    public static let standardContentTypes: [String] = [
        "application/json",
        "application/x-www-form-urlencoded",
        "multipart/form-data",
        "application/xml",
        "text/xml",
        "text/plain",
        "text/html",
        "application/octet-stream",
        "application/graphql+json",
        "application/pdf",
        "image/png",
        "image/jpeg",
        "image/svg+xml"
    ]

    public static func suggestions(for query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(standardHeaderKeys.prefix(8)) }
        return standardHeaderKeys.filter { $0.localizedCaseInsensitiveContains(trimmed) }
    }
}
