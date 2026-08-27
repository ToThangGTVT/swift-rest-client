//
//  ImageViewerView.swift
//  CocoaRestClient
//

import SwiftUI
import AppKit

public struct ImageViewerView: View {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    private var nsImage: NSImage? {
        NSImage(data: data)
    }

    public var body: some View {
        ScrollView([.horizontal, .vertical]) {
            if let image = nsImage {
                VStack(spacing: 12) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: image.size.width > 0 ? image.size.width : 600)
                        .padding()
                        .background(
                            Rectangle()
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(color: .black.opacity(0.1), radius: 4)
                        )
                        .padding()

                    HStack(spacing: 16) {
                        Text("Dimensions: \(Int(image.size.width)) × \(Int(image.size.height)) px")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Size: \(data.count < 1024 ? "\(data.count) B" : String(format: "%.1f KB", Double(data.count) / 1024.0))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("Unable to render image from response data")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}
