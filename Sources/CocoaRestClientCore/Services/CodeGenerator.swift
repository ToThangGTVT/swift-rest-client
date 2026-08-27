//
//  CodeGenerator.swift
//  CocoaRestClientCore
//

import Foundation

public enum CodeLanguage: String, CaseIterable, Identifiable, Sendable {
    case curl = "cURL"
    case swift = "Swift (URLSession)"
    case python = "Python (requests)"
    case javascript = "JavaScript (fetch)"
    case nodeAxios = "Node.js (axios)"
    case go = "Go (net/http)"

    public var id: String { rawValue }
}

public struct CodeGenerator: Sendable {
    public init() {}

    public static func generate(
        language: CodeLanguage,
        request: RestRequest,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        switch language {
        case .curl:
            return CurlCommandGenerator.generate(from: request, environment: environment)
        case .swift:
            return generateSwift(request: request, environment: environment)
        case .python:
            return generatePython(request: request, environment: environment)
        case .javascript:
            return generateJavaScript(request: request, environment: environment)
        case .nodeAxios:
            return generateNodeAxios(request: request, environment: environment)
        case .go:
            return generateGo(request: request, environment: environment)
        }
    }

    private static func generateSwift(request: RestRequest, environment: [String: String]) -> String {
        let resolvedUrl = EnvironmentVariableResolver.resolve(request.url, environment: environment)
        var lines: [String] = [
            "import Foundation",
            "",
            "guard let url = URL(string: \"\(resolvedUrl)\") else { fatalError(\"Invalid URL\") }",
            "var request = URLRequest(url: url)",
            "request.httpMethod = \"\(request.method.rawValue)\""
        ]

        // Headers
        for h in request.headers where h.isEnabled && !h.key.isEmpty {
            let k = EnvironmentVariableResolver.resolve(h.key, environment: environment)
            let v = EnvironmentVariableResolver.resolve(h.value, environment: environment)
            lines.append("request.setValue(\"\(v)\", forHTTPHeaderField: \"\(k)\")")
        }

        // Auth
        switch request.auth.type {
        case .bearer:
            if !request.auth.token.isEmpty {
                let token = EnvironmentVariableResolver.resolve(request.auth.token, environment: environment)
                lines.append("request.setValue(\"Bearer \(token)\", forHTTPHeaderField: \"Authorization\")")
            }
        case .basic:
            if request.auth.hasCredentials {
                let u = EnvironmentVariableResolver.resolve(request.auth.username, environment: environment)
                let p = EnvironmentVariableResolver.resolve(request.auth.password, environment: environment)
                lines.append("let authString = \"\(u):\(p)\".data(using: .utf8)!.base64EncodedString()")
                lines.append("request.setValue(\"Basic \\(authString)\", forHTTPHeaderField: \"Authorization\")")
            }
        default:
            break
        }

        // Body
        let bodyResult = RequestBodyBuilder.build(for: request, environment: environment)
        if let data = bodyResult.data, let bodyStr = String(data: data, encoding: .utf8), !bodyStr.isEmpty {
            if let ct = bodyResult.contentType {
                lines.append("request.setValue(\"\(ct)\", forHTTPHeaderField: \"Content-Type\")")
            }
            let escaped = bodyStr.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            lines.append("request.httpBody = \"\(escaped)\".data(using: .utf8)")
        }

        lines.append("")
        lines.append("let (data, response) = try await URLSession.shared.data(for: request)")
        lines.append("if let httpResponse = response as? HTTPURLResponse {")
        lines.append("    print(\"Status:\", httpResponse.statusCode)")
        lines.append("}")
        lines.append("if let body = String(data: data, encoding: .utf8) {")
        lines.append("    print(\"Response:\", body)")
        lines.append("}")

        return lines.joined(separator: "\n")
    }

    private static func generatePython(request: RestRequest, environment: [String: String]) -> String {
        let resolvedUrl = EnvironmentVariableResolver.resolve(request.url, environment: environment)
        var lines: [String] = [
            "import requests",
            "",
            "url = \"\(resolvedUrl)\"",
            "headers = {"
        ]

        for h in request.headers where h.isEnabled && !h.key.isEmpty {
            let k = EnvironmentVariableResolver.resolve(h.key, environment: environment)
            let v = EnvironmentVariableResolver.resolve(h.value, environment: environment)
            lines.append("    \"\(k)\": \"\(v)\",")
        }
        lines.append("}")

        var authPart = ""
        switch request.auth.type {
        case .basic:
            if request.auth.hasCredentials {
                let u = EnvironmentVariableResolver.resolve(request.auth.username, environment: environment)
                let p = EnvironmentVariableResolver.resolve(request.auth.password, environment: environment)
                authPart = ", auth=(\"\(u)\", \"\(p)\")"
            }
        case .bearer:
            if !request.auth.token.isEmpty {
                let token = EnvironmentVariableResolver.resolve(request.auth.token, environment: environment)
                lines.insert("    \"Authorization\": \"Bearer \(token)\",", at: lines.count - 1)
            }
        default:
            break
        }

        let bodyResult = RequestBodyBuilder.build(for: request, environment: environment)
        var dataPart = ""
        if let data = bodyResult.data, let bodyStr = String(data: data, encoding: .utf8), !bodyStr.isEmpty {
            let escaped = bodyStr.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            lines.append("payload = \"\(escaped)\"")
            dataPart = ", data=payload"
        }

        let method = request.method.rawValue.lowercased()
        lines.append("")
        lines.append("response = requests.\(method)(url, headers=headers\(dataPart)\(authPart))")
        lines.append("print(response.status_code)")
        lines.append("print(response.text)")

        return lines.joined(separator: "\n")
    }

    private static func generateJavaScript(request: RestRequest, environment: [String: String]) -> String {
        let resolvedUrl = EnvironmentVariableResolver.resolve(request.url, environment: environment)
        var lines: [String] = [
            "const url = \"\(resolvedUrl)\";",
            "const options = {",
            "  method: \"\(request.method.rawValue)\",",
            "  headers: {"
        ]

        for h in request.headers where h.isEnabled && !h.key.isEmpty {
            let k = EnvironmentVariableResolver.resolve(h.key, environment: environment)
            let v = EnvironmentVariableResolver.resolve(h.value, environment: environment)
            lines.append("    \"\(k)\": \"\(v)\",")
        }

        switch request.auth.type {
        case .bearer:
            if !request.auth.token.isEmpty {
                let token = EnvironmentVariableResolver.resolve(request.auth.token, environment: environment)
                lines.append("    \"Authorization\": \"Bearer \(token)\",")
            }
        default:
            break
        }

        lines.append("  },")

        let bodyResult = RequestBodyBuilder.build(for: request, environment: environment)
        if let data = bodyResult.data, let bodyStr = String(data: data, encoding: .utf8), !bodyStr.isEmpty {
            let escaped = bodyStr.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            lines.append("  body: \"\(escaped)\",")
        }

        lines.append("};")
        lines.append("")
        lines.append("fetch(url, options)")
        lines.append("  .then(res => res.text())")
        lines.append("  .then(text => console.log(text))")
        lines.append("  .catch(err => console.error(err));")

        return lines.joined(separator: "\n")
    }

    private static func generateNodeAxios(request: RestRequest, environment: [String: String]) -> String {
        let resolvedUrl = EnvironmentVariableResolver.resolve(request.url, environment: environment)
        var lines: [String] = [
            "const axios = require('axios');",
            "",
            "const config = {",
            "  method: '\(request.method.rawValue.lowercased())',",
            "  url: '\(resolvedUrl)',",
            "  headers: {"
        ]

        for h in request.headers where h.isEnabled && !h.key.isEmpty {
            let k = EnvironmentVariableResolver.resolve(h.key, environment: environment)
            let v = EnvironmentVariableResolver.resolve(h.value, environment: environment)
            lines.append("    '\(k)': '\(v)',")
        }
        lines.append("  },")

        let bodyResult = RequestBodyBuilder.build(for: request, environment: environment)
        if let data = bodyResult.data, let bodyStr = String(data: data, encoding: .utf8), !bodyStr.isEmpty {
            let escaped = bodyStr.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: "\\n")
            lines.append("  data: '\(escaped)',")
        }

        lines.append("};")
        lines.append("")
        lines.append("axios(config)")
        lines.append("  .then(response => console.log(JSON.stringify(response.data)))")
        lines.append("  .catch(error => console.log(error));")

        return lines.joined(separator: "\n")
    }

    private static func generateGo(request: RestRequest, environment: [String: String]) -> String {
        let resolvedUrl = EnvironmentVariableResolver.resolve(request.url, environment: environment)
        var lines: [String] = [
            "package main",
            "",
            "import (",
            "    \"fmt\"",
            "    \"io\"",
            "    \"net/http\"",
            "    \"strings\"",
            ")",
            "",
            "func main() {",
            "    url := \"\(resolvedUrl)\""
        ]

        let bodyResult = RequestBodyBuilder.build(for: request, environment: environment)
        if let data = bodyResult.data, let bodyStr = String(data: data, encoding: .utf8), !bodyStr.isEmpty {
            let escaped = bodyStr.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"").replacingOccurrences(of: "\n", with: "\\n")
            lines.append("    payload := strings.NewReader(\"\(escaped)\")")
            lines.append("    req, _ := http.NewRequest(\"\(request.method.rawValue)\", url, payload)")
        } else {
            lines.append("    req, _ := http.NewRequest(\"\(request.method.rawValue)\", url, nil)")
        }

        for h in request.headers where h.isEnabled && !h.key.isEmpty {
            let k = EnvironmentVariableResolver.resolve(h.key, environment: environment)
            let v = EnvironmentVariableResolver.resolve(h.value, environment: environment)
            lines.append("    req.Header.Add(\"\(k)\", \"\(v)\")")
        }

        lines.append("    res, err := http.DefaultClient.Do(req)")
        lines.append("    if err != nil {")
        lines.append("        fmt.Println(err)")
        lines.append("        return")
        lines.append("    }")
        lines.append("    defer res.Body.Close()")
        lines.append("    body, _ := io.ReadAll(res.Body)")
        lines.append("    fmt.Println(res.Status)")
        lines.append("    fmt.Println(string(body))")
        lines.append("}")

        return lines.joined(separator: "\n")
    }
}
