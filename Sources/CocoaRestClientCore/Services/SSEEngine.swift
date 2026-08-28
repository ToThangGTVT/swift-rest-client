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

    /// Headers actually sent, for the console to display.
    @Published public private(set) var sentHeaders: [KeyValuePair] = []

    private var session: URLSession?
    private var dataTask: URLSessionDataTask?
    private var buffer = ""
    /// Id of the last event seen, replayed as `Last-Event-ID` on the next connect
    /// so a reconnect resumes where the stream left off.
    private var lastEventId: String?

    public override init() {
        super.init()
    }

    public func connect(url: URL, headers: [String: String] = [:]) {
        disconnect()
        errorMessage = nil

        let config = URLSessionConfiguration.default
        // A stream has no response deadline, but the values must stay finite:
        // greatestFiniteMagnitude is not a duration URLSession can reason about.
        config.timeoutIntervalForRequest = Self.streamTimeout
        config.timeoutIntervalForResource = Self.streamTimeout
        // Cookies come from the app's own jar via `headers`.
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: .main)

        buffer = ""

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        if let lastEventId {
            request.setValue(lastEventId, forHTTPHeaderField: "Last-Event-ID")
        }
        sentHeaders = (request.allHTTPHeaderFields ?? [:])
            .map { KeyValuePair(key: $0.key, value: $0.value, isEnabled: true) }
            .sorted { $0.key < $1.key }

        self.dataTask = session?.dataTask(with: request)
        dataTask?.resume()
        isConnected = true
    }

    /// One day. Long enough that no stream hits it, short enough to stay a number.
    private static let streamTimeout: TimeInterval = 86_400

    /// Rejects a response that is not an event stream.
    ///
    /// Without this a 401 page is fed straight into the SSE parser, which finds no
    /// `data:` lines and reports nothing at all -- the stream just looks idle.
    public func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.allow)
            return
        }

        guard (200..<300).contains(http.statusCode) else {
            errorMessage = "HTTP \(http.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))"
            isConnected = false
            completionHandler(.cancel)
            return
        }

        let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        guard contentType.contains("text/event-stream") else {
            errorMessage = "Not an event stream -- server replied with \(contentType.isEmpty ? "no Content-Type" : contentType)"
            isConnected = false
            completionHandler(.cancel)
            return
        }

        completionHandler(.allow)
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
                if let eventId { self.lastEventId = eventId }
                self.events.append(event)
            }
        }
    }
}
