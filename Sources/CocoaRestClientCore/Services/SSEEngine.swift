//
//  SSEEngine.swift
//  CocoaRestClientCore
//

import Foundation

public struct SSEEvent: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var event: String
    public var data: String
    public var eventId: String?

    public init(id: UUID = UUID(), timestamp: Date = Date(), event: String = "message", data: String, eventId: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.event = event
        self.data = data
        self.eventId = eventId
    }
}

public final class SSEEngine: NSObject, ObservableObject, URLSessionDataDelegate, @unchecked Sendable {
    @Published public var isConnected: Bool = false
    @Published public var events: [SSEEvent] = []
    @Published public var errorMessage: String?

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var buffer = ""

    public override init() {
        super.init()
    }

    public func connect(url: URL, headers: [String: String] = [:]) {
        disconnect()
        errorMessage = nil

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(Double.greatestFiniteMagnitude)
        config.timeoutIntervalForResource = TimeInterval(Double.greatestFiniteMagnitude)
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }

        self.dataTask = session?.dataTask(with: request)
        dataTask?.resume()
        isConnected = true
    }

    public func disconnect() {
        dataTask?.cancel()
        dataTask = nil
        session?.invalidateAndCancel()
        session = nil
        isConnected = false
    }

    public func clearEvents() {
        events.removeAll()
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        buffer += chunk

        while let range = buffer.range(of: "\n\n") {
            let messageBlock = String(buffer[..<range.lowerBound])
            buffer = String(buffer[range.upperBound...])
            parseSSEMessage(messageBlock)
        }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            if let error = error {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func parseSSEMessage(_ raw: String) {
        var eventType = "message"
        var dataLines: [String] = []
        var eventId: String?

        let lines = raw.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("event:") {
                eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                let d = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                dataLines.append(d)
            } else if line.hasPrefix("id:") {
                eventId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            }
        }

        let combinedData = dataLines.joined(separator: "\n")
        if !combinedData.isEmpty {
            let event = SSEEvent(event: eventType, data: combinedData, eventId: eventId)
            DispatchQueue.main.async {
                self.events.append(event)
            }
        }
    }
}
