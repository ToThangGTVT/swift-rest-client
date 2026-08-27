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

public final class WebSocketEngine: NSObject, ObservableObject, @unchecked Sendable {
    @Published public var state: WebSocketConnectionState = .disconnected
    @Published public var frames: [WebSocketFrame] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    public override init() {
        super.init()
    }

    public func connect(url: URL, headers: [String: String] = [:]) {
        disconnect()
        state = .connecting

        let configuration = URLSessionConfiguration.default
        let session = URLSession(configuration: configuration, delegate: nil, delegateQueue: .main)
        self.urlSession = session

        var request = URLRequest(url: url)
        for (k, v) in headers {
            request.addValue(v, forHTTPHeaderField: k)
        }

        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        task.resume()

        state = .connected
        listenForMessages()
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
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
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
                    if self.state == .connected {
                        self.listenForMessages()
                    }
                case .failure(let error):
                    if self.state == .connected {
                        self.state = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
}
