//
//  StatusBadgeView.swift
//  CocoaRestClientApp
//

import SwiftUI
import CocoaRestClientCore

public struct StatusBadgeView: View {
    public var statusCode: Int
    public var statusDescription: String
    public var latencyMs: Double

    public init(statusCode: Int, statusDescription: String, latencyMs: Double) {
        self.statusCode = statusCode
        self.statusDescription = statusDescription
        self.latencyMs = latencyMs
    }

    private var badgeColor: Color {
        switch statusCode {
        case 200..<300:
            return .green
        case 300..<400:
            return .blue
        case 400..<500:
            return .orange
        case 500..<600:
            return .red
        default:
            return .gray
        }
    }

    public var body: some View {
        HStack(spacing: 8) {
            if statusCode > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(badgeColor)
                        .frame(width: 8, height: 8)
                    Text("\(statusCode) \(statusDescription)")
                        .fontWeight(.semibold)
                        .font(.system(.subheadline, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(badgeColor.opacity(0.15))
                .cornerRadius(6)

                Text(String(format: "%.0f ms", latencyMs))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(4)
            } else {
                Text(statusDescription.isEmpty ? "Ready" : statusDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}
