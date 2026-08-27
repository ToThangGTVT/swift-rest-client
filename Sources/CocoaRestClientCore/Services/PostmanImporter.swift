//
//  PostmanImporter.swift
//  CocoaRestClientCore
//

import Foundation

public struct PostmanImporter: Sendable {
    public init() {}

    public static func importCollection(from jsonData: Data) throws -> RequestFolder {
        guard let rootJson = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw NSError(domain: "PostmanImporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }

        let info = rootJson["info"] as? [String: Any]
        let collectionName = info?["name"] as? String ?? "Postman Collection"

        var rootFolder = RequestFolder(name: collectionName)

        if let items = rootJson["item"] as? [[String: Any]] {
            for item in items {
                if let parsed = parseItem(item) {
                    rootFolder.append(parsed)
                }
            }
        }

        return rootFolder
    }

    private static func parseItem(_ item: [String: Any]) -> RequestTreeItem? {
        let name = item["name"] as? String ?? "Request"

        // Check if this item is a Folder (contains child "item" array)
        if let subItems = item["item"] as? [[String: Any]] {
            var folder = RequestFolder(name: name)
            for sub in subItems {
                if let child = parseItem(sub) {
                    folder.append(child)
                }
            }
            return .folder(folder)
        }

        // Otherwise, it is a Request
        guard let reqDict = item["request"] as? [String: Any] else {
            return nil
        }

        var request = RestRequest(name: name)

        // 1. Method
        if let methodStr = reqDict["method"] as? String {
            request.method = HTTPMethod(methodStr)
        }

        // 2. URL
        if let urlStr = reqDict["url"] as? String {
            request.url = urlStr
        } else if let urlDict = reqDict["url"] as? [String: Any] {
            if let rawUrl = urlDict["raw"] as? String {
                request.url = rawUrl
            }
            if let queryArr = urlDict["query"] as? [[String: Any]] {
                request.urlParams = queryArr.compactMap { q in
                    guard let k = q["key"] as? String else { return nil }
                    let v = q["value"] as? String ?? ""
                    let disabled = q["disabled"] as? Bool ?? false
                    return KeyValuePair(key: k, value: v, isEnabled: !disabled)
                }
            }
        }

        // 3. Headers
        if let headerArr = reqDict["header"] as? [[String: Any]] {
            request.headers = headerArr.compactMap { h in
                guard let k = h["key"] as? String else { return nil }
                let v = h["value"] as? String ?? ""
                let disabled = h["disabled"] as? Bool ?? false
                return KeyValuePair(key: k, value: v, isEnabled: !disabled)
            }
        }

        // 4. Body
        if let bodyDict = reqDict["body"] as? [String: Any] {
            let mode = bodyDict["mode"] as? String ?? "raw"
            switch mode {
            case "raw":
                request.bodyType = .raw
                request.rawBody = bodyDict["raw"] as? String ?? ""
            case "urlencoded":
                request.bodyType = .formUrlEncoded
                if let urlencodedArr = bodyDict["urlencoded"] as? [[String: Any]] {
                    request.params = urlencodedArr.compactMap { p in
                        guard let k = p["key"] as? String else { return nil }
                        let v = p["value"] as? String ?? ""
                        let disabled = p["disabled"] as? Bool ?? false
                        return KeyValuePair(key: k, value: v, isEnabled: !disabled)
                    }
                }
            case "formdata":
                request.bodyType = .multipart
                if let formdataArr = bodyDict["formdata"] as? [[String: Any]] {
                    request.params = formdataArr.compactMap { p in
                        guard let k = p["key"] as? String else { return nil }
                        let v = p["value"] as? String ?? ""
                        let disabled = p["disabled"] as? Bool ?? false
                        return KeyValuePair(key: k, value: v, isEnabled: !disabled)
                    }
                }
            case "graphql":
                request.bodyType = .graphql
                if let gqlDict = bodyDict["graphql"] as? [String: Any] {
                    request.graphqlQuery = gqlDict["query"] as? String ?? ""
                    request.graphqlVariables = gqlDict["variables"] as? String ?? "{}"
                }
            default:
                request.bodyType = .raw
                request.rawBody = bodyDict["raw"] as? String ?? ""
            }
        }

        // 5. Auth
        if let authDict = reqDict["auth"] as? [String: Any] {
            let type = authDict["type"] as? String ?? "noauth"
            switch type {
            case "bearer":
                request.auth.type = .bearer
                if let bearerArr = authDict["bearer"] as? [[String: Any]] {
                    let tokenEntry = bearerArr.first(where: { ($0["key"] as? String) == "token" })
                    request.auth.token = tokenEntry?["value"] as? String ?? ""
                }
            case "basic":
                request.auth.type = .basic
                if let basicArr = authDict["basic"] as? [[String: Any]] {
                    let userEntry = basicArr.first(where: { ($0["key"] as? String) == "username" })
                    let passEntry = basicArr.first(where: { ($0["key"] as? String) == "password" })
                    request.auth.username = userEntry?["value"] as? String ?? ""
                    request.auth.password = passEntry?["value"] as? String ?? ""
                }
            case "apikey":
                request.auth.type = .apiKey
                if let apikeyArr = authDict["apikey"] as? [[String: Any]] {
                    let keyEntry = apikeyArr.first(where: { ($0["key"] as? String) == "key" })
                    let valEntry = apikeyArr.first(where: { ($0["key"] as? String) == "value" })
                    let inEntry = apikeyArr.first(where: { ($0["key"] as? String) == "in" })
                    request.auth.apiKeyName = keyEntry?["value"] as? String ?? ""
                    request.auth.apiKeyValue = valEntry?["value"] as? String ?? ""
                    request.auth.apiKeyLocation = (inEntry?["value"] as? String) == "query" ? .query : .header
                }
            default:
                break
            }
        }

        return .request(request)
    }
}
