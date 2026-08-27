//
//  HistoryItem.swift
//  CocoaRestClientCore
//

import Foundation

public struct HistoryItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var statusCode: Int
    public var latencyMs: Double
    public var responseSize: Int
    public var request: RestRequest

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        statusCode: Int,
        latencyMs: Double,
        responseSize: Int,
        request: RestRequest
    ) {
        self.id = id
        self.timestamp = timestamp
        self.statusCode = statusCode
        self.latencyMs = latencyMs
        self.responseSize = responseSize
        self.request = request
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .short
        return formatter.string(from: timestamp)
    }

    public var formattedSize: String {
        if responseSize < 1024 {
            return "\(responseSize) B"
        } else if responseSize < 1024 * 1024 {
            return String(format: "%.1f KB", Double(responseSize) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(responseSize) / (1024.0 * 1024.0))
        }
    }
}
