//
//  SavedRequestsStore.swift
//  CocoaRestClientCore
//

import Foundation

public final class SavedRequestsStore: @unchecked Sendable {
    public static let shared = SavedRequestsStore()

    private let fileManager = FileManager.default
    private let appSupportDirName = "CocoaRestClient"
    private let jsonFileName = "CocoaRestClient.savedRequests.json"
    private let legacyFileName = "CocoaRestClient.savedRequests"

    public var appSupportDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent(appSupportDirName, isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }
        return dir
    }

    public var jsonFileURL: URL {
        appSupportDirectory.appendingPathComponent(jsonFileName)
    }

    public var legacyFileURL: URL {
        appSupportDirectory.appendingPathComponent(legacyFileName)
    }

    public func loadRootFolder() -> RequestFolder {
        // 1. Try loading from JSON
        if fileManager.fileExists(atPath: jsonFileURL.path) {
            if let data = try? Data(contentsOf: jsonFileURL) {
                let decoder = JSONDecoder()
                if let folder = try? decoder.decode(RequestFolder.self, from: data) {
                    return folder
                }
            }
        }

        // 2. Try migrating from legacy NSKeyedArchiver file if it exists
        if fileManager.fileExists(atPath: legacyFileURL.path) {
            if let migrated = migrateLegacyFile() {
                saveRootFolder(migrated)
                return migrated
            }
        }

        // 3. Fallback: Default starter collection
        let defaultCollection = createDefaultCollection()
        saveRootFolder(defaultCollection)
        return defaultCollection
    }

    public func saveRootFolder(_ folder: RequestFolder) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(folder)
            try data.write(to: jsonFileURL, options: .atomic)
        } catch {
            print("Failed to save requests to \(jsonFileURL.path): \(error)")
        }
    }

    public func exportFolder(_ folder: RequestFolder, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(folder)
        try data.write(to: url, options: .atomic)
    }

    public func importFolder(from url: URL) throws -> RequestFolder {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(RequestFolder.self, from: data)
    }

    private func createDefaultCollection() -> RequestFolder {
        var root = RequestFolder(name: "Saved Requests")
        
        var demoFolder = RequestFolder(name: "Demo APIs")
        demoFolder.append(.request(RestRequest(
            name: "HTTPBin GET",
            url: "https://httpbin.org/get",
            method: .get,
            headers: [
                KeyValuePair(key: "Accept", value: "application/json", isEnabled: true)
            ]
        )))
        
        demoFolder.append(.request(RestRequest(
            name: "HTTPBin POST JSON",
            url: "https://httpbin.org/post",
            method: .post,
            headers: [
                KeyValuePair(key: "Content-Type", value: "application/json", isEnabled: true)
            ],
            bodyType: .raw,
            rawBody: "{\n  \"message\": \"Hello from Swift CocoaRestClient!\",\n  \"status\": \"success\"\n}",
            rawBodyContentType: "application/json"
        )))
        
        demoFolder.append(.request(RestRequest(
            name: "HTTPBin Form URL-Encoded",
            url: "https://httpbin.org/post",
            method: .post,
            params: [
                KeyValuePair(key: "username", value: "testuser", isEnabled: true),
                KeyValuePair(key: "email", value: "test@example.com", isEnabled: true)
            ],
            bodyType: .formUrlEncoded
        )))

        root.append(.folder(demoFolder))
        return root
    }

    private func migrateLegacyFile() -> RequestFolder? {
        guard let data = try? Data(contentsOf: legacyFileURL) else { return nil }
        
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            if let topLevelArray = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? NSArray {
                var root = RequestFolder(name: "Migrated Requests")
                for item in topLevelArray {
                    if let converted = convertLegacyItem(item) {
                        root.append(converted)
                    }
                }
                return root
            }
        } catch {
            print("Failed to unarchive legacy requests: \(error)")
        }
        return nil
    }

    private func convertLegacyItem(_ item: Any) -> RequestTreeItem? {
        if let dict = item as? [String: Any] {
            let name = dict["name"] as? String ?? "Unnamed Request"
            let url = dict["url"] as? String ?? ""
            let method = dict["method"] as? String ?? "GET"
            let body = dict["body"] as? String ?? ""
            let username = dict["username"] as? String ?? ""
            let password = dict["password"] as? String ?? ""
            
            var req = RestRequest(name: name, url: url, method: HTTPMethod(method))
            req.rawBody = body
            req.auth = Authentication(
                type: (!username.isEmpty || !password.isEmpty) ? .basic : .none,
                username: username,
                password: password,
                token: "",
                isPreemptive: false
            )
            return .request(req)
        }
        return nil
    }
}
