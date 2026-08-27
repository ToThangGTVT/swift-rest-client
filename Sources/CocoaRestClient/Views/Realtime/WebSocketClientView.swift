//
//  WebSocketClientView.swift
//  CocoaRestClient
//

import SwiftUI
import CocoaRestClientCore
import AppKit

public struct WebSocketClientView: View {
    @StateObject private var wsEngine = WebSocketEngine()
    @StateObject private var sseEngine = SSEEngine()

    @State private var protocolMode: ProtocolMode = .webSocket
    @State private var urlString: String = "wss://echo.websocket.events"
    @State private var outgoingMessage: String = "{\n  \"message\": \"Hello from CocoaRestClient!\"\n}"
    @State private var searchFilter: String = ""

    private enum ProtocolMode: String, CaseIterable, Identifiable {
        case webSocket = "WebSocket (WS/WSS)"
        case sse = "Server-Sent Events (SSE)"

        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 10) {
                Picker("", selection: $protocolMode) {
                    ForEach(ProtocolMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 250)

                TextField("URL (e.g. wss://... or https://.../events)", text: $urlString)
                    .textFieldStyle(.roundedBorder)

                if isConnected {
                    Button("Disconnect", role: .destructive) {
                        disconnect()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                } else {
                    Button("Connect") {
                        connect()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
            }
            .padding(10)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Status Indicator
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Filter
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Filter messages...", text: $searchFilter)
                        .textFieldStyle(.plain)
                        .frame(width: 140)
                }
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)

                Button("Clear") {
                    wsEngine.clearFrames()
                    sseEngine.clearEvents()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

            Divider()

            // Main Content: Split between Messages Log and Message Composer
            HSplitView {
                // Left Pane: Message Log
                VStack(spacing: 0) {
                    if protocolMode == .webSocket {
                        wsMessagesList
                    } else {
                        sseMessagesList
                    }
                }
                .frame(minWidth: 320, maxWidth: .infinity)

                // Right Pane: Send Message (WebSocket only)
                if protocolMode == .webSocket {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Send Message")
                                .font(.headline)
                            Spacer()
                            Button("Send") {
                                wsEngine.send(text: outgoingMessage)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!isConnected)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 8)

                        TextEditor(text: $outgoingMessage)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(6)
                            .padding(.horizontal, 10)
                            .padding(.bottom, 10)
                    }
                    .frame(minWidth: 260, maxWidth: 400)
                }
            }
        }
    }

    private var wsMessagesList: some View {
        Group {
            let filtered = wsEngine.frames.filter {
                searchFilter.isEmpty || $0.content.localizedCaseInsensitiveContains(searchFilter)
            }

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No WebSocket frames received yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { frame in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(frame.direction.rawValue)
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(frame.direction == .incoming ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                                    .foregroundColor(frame.direction == .incoming ? .green : .blue)
                                    .cornerRadius(3)

                                Text(timeFormatter.string(from: frame.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(frame.content, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }

                            Text(frame.content)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var sseMessagesList: some View {
        Group {
            let filtered = sseEngine.events.filter {
                searchFilter.isEmpty || $0.data.localizedCaseInsensitiveContains(searchFilter) || $0.event.localizedCaseInsensitiveContains(searchFilter)
            }

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No SSE events received yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(event.event.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(3)

                                if let id = event.eventId {
                                    Text("id: \(id)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Text(timeFormatter.string(from: event.timestamp))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                Spacer()
                            }

                            Text(event.data)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var isConnected: Bool {
        if protocolMode == .webSocket {
            return wsEngine.state == .connected
        } else {
            return sseEngine.isConnected
        }
    }

    private var statusColor: Color {
        if protocolMode == .webSocket {
            switch wsEngine.state {
            case .connected: return .green
            case .connecting: return .orange
            case .disconnected: return .gray
            case .error: return .red
            }
        } else {
            return sseEngine.isConnected ? .green : .gray
        }
    }

    private var statusText: String {
        if protocolMode == .webSocket {
            switch wsEngine.state {
            case .connected: return "Connected"
            case .connecting: return "Connecting..."
            case .disconnected: return "Disconnected"
            case .error(let err): return "Error: \(err)"
            }
        } else {
            if let err = sseEngine.errorMessage {
                return "Error: \(err)"
            }
            return sseEngine.isConnected ? "Streaming events..." : "Disconnected"
        }
    }

    private func connect() {
        guard let url = URL(string: urlString) else { return }
        if protocolMode == .webSocket {
            wsEngine.connect(url: url)
        } else {
            sseEngine.connect(url: url)
        }
    }

    private func disconnect() {
        if protocolMode == .webSocket {
            wsEngine.disconnect()
        } else {
            sseEngine.disconnect()
        }
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }
}
