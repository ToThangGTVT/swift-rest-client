//
//  HTTPMethod.swift
//  CocoaRestClientCore
//

import Foundation

public struct HTTPMethod: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public init(_ string: String) {
        self.init(rawValue: string)
    }

    public var description: String { rawValue }

    public static let get = HTTPMethod("GET")
    public static let post = HTTPMethod("POST")
    public static let put = HTTPMethod("PUT")
    public static let delete = HTTPMethod("DELETE")
    public static let head = HTTPMethod("HEAD")
    public static let options = HTTPMethod("OPTIONS")
    public static let patch = HTTPMethod("PATCH")
    public static let copy = HTTPMethod("COPY")
    public static let search = HTTPMethod("SEARCH")

    public static let allPredefined: [HTTPMethod] = [
        .get, .post, .put, .delete, .head, .options, .patch, .copy, .search
    ]

    public var allowsBody: Bool {
        switch self {
        case .get, .head:
            return false
        default:
            return true
        }
    }
}
