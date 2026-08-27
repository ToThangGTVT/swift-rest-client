//
//  OpenAPIImporter.swift
//  CocoaRestClientCore
//

import Foundation

public struct OpenAPIImporter: Sendable {
    public init() {}

    public static func importSpecification(from jsonData: Data) throws -> RequestFolder {
        guard let rootJson = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw NSError(domain: "OpenAPIImporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }

        let info = rootJson["info"] as? [String: Any]
        let title = info?["title"] as? String ?? "OpenAPI Specification"

        // Base URL resolution
        var baseUrl = ""
        if let servers = rootJson["servers"] as? [[String: Any]], let firstServer = servers.first?["url"] as? String {
            baseUrl = firstServer
        } else if let host = rootJson["host"] as? String {
            let scheme = (rootJson["schemes"] as? [String])?.first ?? "https"
            let basePath = rootJson["basePath"] as? String ?? ""
            baseUrl = "\(scheme)://\(host)\(basePath)"
        }

        var rootFolder = RequestFolder(name: title)
        var taggedFolders: [String: RequestFolder] = [:]
        var untaggedRequests: [RestRequest] = []

        if let paths = rootJson["paths"] as? [String: [String: Any]] {
            for (pathString, pathItem) in paths {
                let supportedMethods: [(String, HTTPMethod)] = [
                    ("get", .get), ("post", .post), ("put", .put),
                    ("delete", .delete), ("patch", .patch),
                    ("head", .head), ("options", .options)
                ]

                for (methodKey, httpMethod) in supportedMethods {
                    guard let opDict = pathItem[methodKey] as? [String: Any] else { continue }

                    let summary = opDict["summary"] as? String
                    let opId = opDict["operationId"] as? String
                    let reqName = summary ?? opId ?? "\(httpMethod.rawValue) \(pathString)"

                    var request = RestRequest(name: reqName)
                    request.method = httpMethod
                    
                    let fullUrl: String
                    if baseUrl.isEmpty {
                        fullUrl = pathString
                    } else {
                        let trimmedBase = baseUrl.hasSuffix("/") ? String(baseUrl.dropLast()) : baseUrl
                        let trimmedPath = pathString.hasPrefix("/") ? pathString : "/\(pathString)"
                        fullUrl = "\(trimmedBase)\(trimmedPath)"
                    }
                    request.url = fullUrl

                    // Parameters
                    if let params = opDict["parameters"] as? [[String: Any]] {
                        for p in params {
                            guard let pName = p["name"] as? String else { continue }
                            let pIn = p["in"] as? String ?? "query"
                            let req = p["required"] as? Bool ?? false
                            let example = (p["example"] as? String) ?? (p["default"] as? String) ?? ""

                            if pIn == "query" {
                                request.urlParams.append(KeyValuePair(key: pName, value: example, isEnabled: req))
                            } else if pIn == "header" {
                                request.headers.append(KeyValuePair(key: pName, value: example, isEnabled: req))
                            }
                        }
                    }

                    // Request Body (OpenAPI 3)
                    if let reqBody = opDict["requestBody"] as? [String: Any],
                       let content = reqBody["content"] as? [String: [String: Any]] {
                        if let jsonContent = content["application/json"] {
                            request.bodyType = .raw
                            if !request.headers.contains(where: { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }) {
                                request.headers.append(KeyValuePair(key: "Content-Type", value: "application/json"))
                            }
                            if let example = jsonContent["example"] {
                                if let exampleData = try? JSONSerialization.data(withJSONObject: example, options: .prettyPrinted),
                                   let exampleStr = String(data: exampleData, encoding: .utf8) {
                                    request.rawBody = exampleStr
                                }
                            } else {
                                request.rawBody = "{\n  \n}"
                            }
                        }
                    }

                    // Organize into tag folder or root
                    let tags = opDict["tags"] as? [String]
                    if let firstTag = tags?.first, !firstTag.isEmpty {
                        if taggedFolders[firstTag] == nil {
                            taggedFolders[firstTag] = RequestFolder(name: firstTag)
                        }
                        taggedFolders[firstTag]?.append(.request(request))
                    } else {
                        untaggedRequests.append(request)
                    }
                }
            }
        }

        // Add sorted tagged folders
        for key in taggedFolders.keys.sorted() {
            if let folder = taggedFolders[key] {
                rootFolder.append(.folder(folder))
            }
        }

        // Add untagged requests
        for req in untaggedRequests {
            rootFolder.append(.request(req))
        }

        return rootFolder
    }
}
