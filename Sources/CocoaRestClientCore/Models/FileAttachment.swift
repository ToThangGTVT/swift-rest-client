//
//  FileAttachment.swift
//  CocoaRestClientCore
//

import Foundation
import UniformTypeIdentifiers

public struct FileAttachment: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var key: String
    public var filePath: String
    public var customMimeType: String?
    public var isGzipped: Bool
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        key: String = "",
        filePath: String = "",
        customMimeType: String? = nil,
        isGzipped: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.key = key
        self.filePath = filePath
        self.customMimeType = customMimeType
        self.isGzipped = isGzipped
        self.isEnabled = isEnabled
    }

    public var fileName: String {
        URL(fileURLWithPath: filePath).lastPathComponent
    }

    public var resolvedMimeType: String {
        if let custom = customMimeType, !custom.isEmpty {
            return custom
        }
        if isGzipped {
            return "application/x-gzip"
        }
        let ext = URL(fileURLWithPath: filePath).pathExtension
        if let utType = UTType(filenameExtension: ext), let mime = utType.preferredMIMEType {
            return mime
        }
        return "application/octet-stream"
    }

    public var fileExists: Bool {
        guard !filePath.isEmpty else { return false }
        return FileManager.default.fileExists(atPath: filePath)
    }
}
