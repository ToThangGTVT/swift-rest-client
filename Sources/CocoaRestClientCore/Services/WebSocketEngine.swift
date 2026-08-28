//
//  WebSocketEngine.swift
//  CocoaRestClientCore
//

import Foundation
import Combine

public struct WebSocketFrame: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var direction: Direction
    public var content: String
    public var isBinary: Bool

    public enum Direction: String, Codable, Sendable {
        case incoming = "IN"
        case outgoing = "OUT"
    }

    public init(id: UUID = UUID(), timestamp: Date = Date(), direction: Direction, content: String, isBinary: Bool = false) {
        self.id = id
        self.timestamp = timestamp
        self.direction = direction
        self.content = content
        self.isBinary = isBinary
    }
}

public enum WebSocketConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

public final class WebSocketEngine: NSObject, ObservableObject, URLSessionWebSocketDelegate, @unchecked Sendable {
    @Published public var state: WebSocketConnectionState = .disconnected
    @Published public var frames: [WebSocketFrame] = []

    /// Headers actually sent on the handshake, for the console to display.
    @Published public private(set) var sentHeaders: [KeyValuePair] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    public override init() {
        super.init()
    }

    public func connect(url: URL, headers: [String: String] = [:]) {
        disconnect()
        state = .connecting

        let configuration = URLSessionConfiguration.default
        // The engine injects the app's own cookie jar explicitly; letting URLSession
        // add a second set from its shared storage would send both.
        configuration.httpShouldSetCookies = false
        configuration.httpCookieStorage = nil
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        self.urlSession = session

        var request = URLRequest(url: url)
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        sentHeaders = (request.allHTTPHeaderFields ?? [:])
            .map { KeyValuePair(key: $0.key, value: $0.value, isEnabled: true) }
            .sorted { $0.key < $1.key }

        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()

        // Stay in .connecting until the delegate reports the handshake opened.
        // Flipping to .connected here reports success for a server that answered
        // 401, and the failure only surfaces later as a receive error.
        listenForMessages()
    }

    // MARK: - URLSessionWebSocketDelegate

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        guard webSocketTask === self.webSocketTask else { return }
        state = .connected
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        guard webSocketTask === self.webSocketTask else { return }
        let detail = reason.flatMap { String(data: $0, encoding: .utf8) }.flatMap { $0.isEmpty ? nil : $0 }
        state = closeCode == .normalClosure || closeCode == .goingAway
            ? .disconnected
            : .error("Closed by server (code \(closeCode.rawValue))\(detail.map { ": \($0)" } ?? "")")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard task === self.webSocketTask else { return }
        // A handshake rejected with an HTTP error never opens, so report the status.
        if let http = task.response as? HTTPURLResponse, http.statusCode >= 400 {
            state = .error("Handshake rejected: HTTP \(http.statusCode) \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))")
        } else if let error, state != .disconnected {
            state = .error(error.localizedDescription)
        }
    }

    public func send(text: String) {
        guard state == .connected, let task = webSocketTask else { return }
        let message = URLSessionWebSocketTask.Message.string(text)
        task.send(message) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.state = .error(error.localizedDescription)
                } else {
                    let frame = WebSocketFrame(direction: .outgoing, content: text)
                    self?.frames.append(frame)
                }
            }
        }
    }

    public func disconnect() {
        let task = webSocketTask
        webSocketTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        urlSession?.invalidateAndCancel()
        urlSession = nil
        state = .disconnected
    }

    public func clearFrames() {
        frames.removeAll()
    }

    private func listenForMessages() {
        guard let task = webSocketTask else { return }
        task.receive { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        let frame = WebSocketFrame(direction: .incoming, content: text)
                        self.frames.append(frame)
                    case .data(let data):
                        let text = String(data: data, encoding: .utf8) ?? "<Binary Data (\(data.count) bytes)>"
                        let frame = WebSocketFrame(direction: .incoming, content: text, isBinary: true)
                        self.frames.append(frame)
                    @unknown default:
                        break
                    }
                    // Continue listening for next message
                    if self.webSocketTask != nil {
                        self.listenForMessages()
                    }
                case .failure(let error):
                    // didCompleteWithError reports handshake rejections with the HTTP
                    // status, which is more useful than the generic socket error.
                    if self.webSocketTask != nil, self.state == .connected {
                        self.state = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
}
