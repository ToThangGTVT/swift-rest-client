//
//  RequestFolder.swift
//  CocoaRestClientCore
//

import Foundation

public enum RequestTreeItem: Identifiable, Codable, Hashable, Sendable {
    case request(RestRequest)
    case folder(RequestFolder)

    private enum CodingKeys: String, CodingKey {
        case type, request, folder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        if type == "folder" {
            let folder = try container.decode(RequestFolder.self, forKey: .folder)
            self = .folder(folder)
        } else {
            let req = try container.decode(RestRequest.self, forKey: .request)
            self = .request(req)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .request(let req):
            try container.encode("request", forKey: .type)
            try container.encode(req, forKey: .request)
        case .folder(let folder):
            try container.encode("folder", forKey: .type)
            try container.encode(folder, forKey: .folder)
        }
    }

    public var id: UUID {
        switch self {
        case .request(let req): return req.id
        case .folder(let folder): return folder.id
        }
    }

    public var name: String {
        get {
            switch self {
            case .request(let req): return req.name
            case .folder(let folder): return folder.name
            }
        }
        set {
            switch self {
            case .request(var req):
                req.name = newValue
                self = .request(req)
            case .folder(var folder):
                folder.name = newValue
                self = .folder(folder)
            }
        }
    }

    public var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }

    public var requestValue: RestRequest? {
        if case .request(let req) = self { return req }
        return nil
    }

    public var folderValue: RequestFolder? {
        if case .folder(let f) = self { return f }
        return nil
    }
}

public struct RequestFolder: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var items: [RequestTreeItem]
    public var isExpanded: Bool

    public init(
        id: UUID = UUID(),
        name: String = "New Folder",
        items: [RequestTreeItem] = [],
        isExpanded: Bool = true
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.isExpanded = isExpanded
    }

    public var totalRequestCount: Int {
        items.reduce(0) { count, item in
            switch item {
            case .request:
                return count + 1
            case .folder(let f):
                return count + f.totalRequestCount
            }
        }
    }

    public mutating func append(_ item: RequestTreeItem) {
        items.append(item)
    }

    public mutating func insert(_ item: RequestTreeItem, at index: Int) {
        if index >= 0 && index <= items.count {
            items.insert(item, at: index)
        } else {
            items.append(item)
        }
    }

    public mutating func removeItem(withId id: UUID) -> Bool {
        if let idx = items.firstIndex(where: { $0.id == id }) {
            items.remove(at: idx)
            return true
        }
        for i in 0..<items.count {
            if case .folder(var subFolder) = items[i] {
                if subFolder.removeItem(withId: id) {
                    items[i] = .folder(subFolder)
                    return true
                }
            }
        }
        return false
    }

    public func findItem(withId id: UUID) -> RequestTreeItem? {
        for item in items {
            if item.id == id { return item }
            if case .folder(let sub) = item, let found = sub.findItem(withId: id) {
                return found
            }
        }
        return nil
    }

    public func allRequests(prefixPath: String = "/") -> [(path: String, request: RestRequest)] {
        var results: [(path: String, request: RestRequest)] = []
        for item in items {
            switch item {
            case .request(let req):
                results.append((path: prefixPath, request: req))
            case .folder(let subFolder):
                let nextPath = "\(prefixPath)\(subFolder.name)/"
                results.append(contentsOf: subFolder.allRequests(prefixPath: nextPath))
            }
        }
        return results
    }
}
