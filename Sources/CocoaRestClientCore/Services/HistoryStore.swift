//
//  HistoryStore.swift
//  CocoaRestClientCore
//

import Foundation

public final class HistoryStore: @unchecked Sendable {
    public static let shared = HistoryStore()
    
    private let fileManager = FileManager.default
    private let maxHistoryCount = 100
    private let lock = NSLock()
    
    private var historyFileUrl: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("CocoaRestClient", isDirectory: true)
        if !fileManager.fileExists(atPath: appDir.path) {
            try? fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent("CocoaRestClient.history.json")
    }

    public init() {}

    public func loadHistory() -> [HistoryItem] {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: historyFileUrl.path),
              let data = try? Data(contentsOf: historyFileUrl) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HistoryItem].self, from: data)) ?? []
    }

    public func saveHistory(_ items: [HistoryItem]) {
        lock.lock()
        defer { lock.unlock() }

        let trimmed = Array(items.prefix(maxHistoryCount))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(trimmed) {
            try? data.write(to: historyFileUrl, options: .atomic)
        }
    }

    public func addEntry(request: RestRequest, statusCode: Int, latencyMs: Double, responseSize: Int) {
        var items = loadHistory()
        let newItem = HistoryItem(
            timestamp: Date(),
            statusCode: statusCode,
            latencyMs: latencyMs,
            responseSize: responseSize,
            request: request
        )
        items.insert(newItem, at: 0)
        saveHistory(items)
    }

    public func clearHistory() {
        saveHistory([])
    }
}
