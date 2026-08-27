//
//  EnvironmentProfile.swift
//  CocoaRestClientCore
//

import Foundation

public struct EnvironmentProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var variables: [KeyValuePair]

    public init(
        id: UUID = UUID(),
        name: String,
        variables: [KeyValuePair] = []
    ) {
        self.id = id
        self.name = name
        self.variables = variables
    }

    public func asDictionary() -> [String: String] {
        var dict: [String: String] = [:]
        for item in variables where item.isEnabled && !item.key.isEmpty {
            dict[item.key] = item.value
        }
        return dict
    }
}
