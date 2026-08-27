//
//  KeyValuePair.swift
//  CocoaRestClientCore
//

import Foundation

public struct KeyValuePair: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var key: String
    public var value: String
    public var isEnabled: Bool

    public init(id: UUID = UUID(), key: String = "", value: String = "", isEnabled: Bool = true) {
        self.id = id
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}
