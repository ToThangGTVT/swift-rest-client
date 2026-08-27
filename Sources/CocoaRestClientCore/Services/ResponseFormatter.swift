//
//  ResponseFormatter.swift
//  CocoaRestClientCore
//

import Foundation

public enum ContentTypeCategory: String, Sendable {
    case json
    case xml
    case html
    case image
    case plainText
    case binary
    case unknown
}

public struct ResponseFormatter: Sendable {
    public init() {}

    public static func categorize(contentType: String?) -> ContentTypeCategory {
        guard let raw = contentType?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return .unknown
        }
        let mime = raw.components(separatedBy: ";").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? raw
        
        if mime == "application/json" || mime == "text/json" || mime.hasSuffix("+json") || mime.contains("/json") {
            return .json
        }
        if mime == "application/xml" || mime == "text/xml" || mime.hasSuffix("+xml") || mime.contains("/xml") ||
            mime == "application/atom+xml" || mime == "application/rss+xml" || mime == "application/soap+xml" {
            return .xml
        }
        if mime == "text/html" || mime == "application/xhtml+xml" {
            return .html
        }
        if mime.hasPrefix("image/") {
            return .image
        }
        if mime.hasPrefix("text/") || mime == "application/javascript" || mime == "application/x-javascript" {
            return .plainText
        }
        return .unknown
    }

    public static func format(data: Data, contentType: String?) -> String {
        guard !data.isEmpty else { return "" }
        let category = categorize(contentType: contentType)

        switch category {
        case .json:
            if let formatted = formatJson(data: data) {
                return formatted
            }
        case .xml:
            if let formatted = formatXml(data: data) {
                return formatted
            }
        default:
            break
        }

        // Default: Plain text decode
        return decodePlainText(data: data)
    }

    public static func formatJson(data: Data) -> String? {
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            var writingOptions: JSONSerialization.WritingOptions = [.prettyPrinted]
            if #available(macOS 10.15, *) {
                writingOptions.insert(.withoutEscapingSlashes)
            }
            let prettyData = try JSONSerialization.data(withJSONObject: jsonObject, options: writingOptions)
            return String(data: prettyData, encoding: .utf8)
        } catch {
            return nil
        }
    }

    public static func formatJson(_ string: String) -> String? {
        guard let data = string.data(using: .utf8) else { return nil }
        return formatJson(data: data)
    }

    public static func formatXml(data: Data) -> String? {
        do {
            let xmlDoc = try XMLDocument(data: data, options: [.nodePreserveAll])
            return xmlDoc.xmlString(options: [.nodePrettyPrint])
        } catch {
            return nil
        }
    }

    public static func formatXml(_ string: String) -> String? {
        guard let data = string.data(using: .utf8) else { return nil }
        return formatXml(data: data)
    }

    public static func decodePlainText(data: Data) -> String {
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(data: data, encoding: .isoLatin1) {
            return latin1
        }
        if let windows1252 = String(data: data, encoding: .windowsCP1252) {
            return windows1252
        }
        if let utf16 = String(data: data, encoding: .utf16) {
            return utf16
        }
        return "[\(data.count) bytes binary data - unable to display as text]"
    }

    public static func formatBytes(_ count: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(count))
    }
}
