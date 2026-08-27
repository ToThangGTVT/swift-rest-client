//
//  CurlParser.swift
//  CocoaRestClientCore
//

import Foundation

public struct CurlParser: Sendable {
    public init() {}

    public static func parse(_ command: String) throws -> RestRequest {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "CurlParser", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty command"])
        }

        let tokens = tokenize(trimmed)
        guard !tokens.isEmpty else {
            throw NSError(domain: "CurlParser", code: 2, userInfo: [NSLocalizedDescriptionKey: "No tokens found"])
        }

        var req = RestRequest()
        req.name = "Imported from cURL"
        var explicitMethod: HTTPMethod?
        var foundUrl: String?
        var customHeaders: [KeyValuePair] = []
        var rawDataPieces: [String] = []
        var formParams: [KeyValuePair] = []
        var formFiles: [FileAttachment] = []

        var i = 0
        // Skip leading 'curl' if present
        if tokens[0].lowercased() == "curl" {
            i = 1
        }

        while i < tokens.count {
            let token = tokens[i]

            if token == "-X" || token == "--request" {
                if i + 1 < tokens.count {
                    explicitMethod = HTTPMethod(tokens[i + 1].uppercased())
                    i += 2
                    continue
                }
            } else if token == "-H" || token == "--header" {
                if i + 1 < tokens.count {
                    let headerStr = tokens[i + 1]
                    if let colonIndex = headerStr.firstIndex(of: ":") {
                        let k = String(headerStr[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        let v = String(headerStr[headerStr.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        if !k.isEmpty {
                            customHeaders.append(KeyValuePair(key: k, value: v, isEnabled: true))
                        }
                    }
                    i += 2
                    continue
                }
            } else if token == "-u" || token == "--user" {
                if i + 1 < tokens.count {
                    let authStr = tokens[i + 1]
                    let parts = authStr.components(separatedBy: ":")
                    let user = parts.first ?? ""
                    let pass = parts.count > 1 ? parts[1...].joined(separator: ":") : ""
                    req.auth = Authentication(type: .basic, username: user, password: pass, token: "", isPreemptive: true)
                    i += 2
                    continue
                }
            } else if token == "-d" || token == "--data" || token == "--data-raw" || token == "--data-binary" || token == "--data-ascii" {
                if i + 1 < tokens.count {
                    rawDataPieces.append(tokens[i + 1])
                    i += 2
                    continue
                }
            } else if token == "-F" || token == "--form" {
                if i + 1 < tokens.count {
                    let formStr = tokens[i + 1]
                    if let eqIndex = formStr.firstIndex(of: "=") {
                        let k = String(formStr[..<eqIndex]).trimmingCharacters(in: .whitespaces)
                        let v = String(formStr[formStr.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
                        if v.hasPrefix("@") {
                            let filePath = String(v.dropFirst())
                            formFiles.append(FileAttachment(key: k, filePath: filePath, isGzipped: false, isEnabled: true))
                        } else {
                            formParams.append(KeyValuePair(key: k, value: v, isEnabled: true))
                        }
                    }
                    i += 2
                    continue
                }
            } else if token == "-k" || token == "--insecure" || token == "-L" || token == "--location" || token == "-s" || token == "--silent" || token == "-v" || token == "--verbose" || token == "--compressed" {
                // Ignore supported CLI flags
                i += 1
                continue
            } else if token.hasPrefix("-") {
                // Skip unrecognized flag and its potential argument
                i += 1
                continue
            } else {
                // Positional token: likely URL
                if foundUrl == nil && (token.hasPrefix("http://") || token.hasPrefix("https://") || token.contains(".")) {
                    foundUrl = token
                }
                i += 1
                continue
            }
        }

        if let u = foundUrl {
            req.url = u
            req.parseUrlParameters()
        }

        // Set Headers
        if !customHeaders.isEmpty {
            req.headers = customHeaders
        }

        // Check Bearer Auth header
        if let authHeader = customHeaders.first(where: { $0.key.caseInsensitiveCompare("Authorization") == .orderedSame }) {
            if authHeader.value.lowercased().hasPrefix("bearer ") {
                let token = String(authHeader.value.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                req.auth = Authentication(type: .bearer, username: "", password: "", token: token)
            }
        }

        // Determine Body and Method
        if !formFiles.isEmpty {
            req.bodyType = .multipart
            req.files = formFiles
            req.params = formParams
            req.method = explicitMethod ?? .post
        } else if !formParams.isEmpty {
            req.bodyType = .multipart
            req.params = formParams
            req.method = explicitMethod ?? .post
        } else if !rawDataPieces.isEmpty {
            let combinedBody = rawDataPieces.joined(separator: "&")
            req.rawBody = combinedBody
            req.bodyType = .raw
            req.method = explicitMethod ?? .post
            
            // Check if body is GraphQL
            if let data = combinedBody.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let q = json["query"] as? String {
                req.bodyType = .graphql
                req.graphqlQuery = q
                if let vars = json["variables"] as? [String: Any],
                   let varsData = try? JSONSerialization.data(withJSONObject: vars, options: [.prettyPrinted]),
                   let varsStr = String(data: varsData, encoding: .utf8) {
                    req.graphqlVariables = varsStr
                }
            }
        } else {
            req.method = explicitMethod ?? .get
        }

        return req
    }

    private static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var isEscaped = false

        let chars = Array(input)
        var i = 0

        while i < chars.count {
            let c = chars[i]

            if isEscaped {
                currentToken.append(c)
                isEscaped = false
                i += 1
                continue
            }

            if c == "\\" {
                // If it's a line continuation (\ followed by newline)
                if i + 1 < chars.count && (chars[i + 1] == "\n" || chars[i + 1] == "\r") {
                    i += 2
                    continue
                }
                isEscaped = true
                i += 1
                continue
            }

            if c == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                i += 1
                continue
            }

            if c == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                i += 1
                continue
            }

            if c.isWhitespace && !inSingleQuote && !inDoubleQuote {
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            } else {
                currentToken.append(c)
            }

            i += 1
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }
}
