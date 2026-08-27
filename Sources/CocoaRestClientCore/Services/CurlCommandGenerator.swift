//
//  CurlCommandGenerator.swift
//  CocoaRestClientCore
//

import Foundation

public struct CurlCommandGenerator: Sendable {
    public init() {}

    public static func generate(
        from request: RestRequest,
        followRedirects: Bool = true,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String {
        var parts: [String] = ["curl -k"]
        
        if followRedirects {
            parts.append("-L")
        }
        
        if request.method != .get {
            parts.append("-X \(request.method.rawValue)")
        }
        
        // Headers
        for header in request.headers where header.isEnabled && !header.key.isEmpty {
            let key = EnvironmentVariableResolver.resolve(header.key, environment: environment)
            let value = EnvironmentVariableResolver.resolve(header.value, environment: environment)
            
            if key.caseInsensitiveCompare("accept-encoding") == .orderedSame {
                parts.append("--compressed")
            }
            let escapedValue = value.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("-H '\(key): \(escapedValue)'")
        }
        
        // Authentication
        switch request.auth.type {
        case .basic, .digest:
            if request.auth.hasCredentials {
                let user = EnvironmentVariableResolver.resolve(request.auth.username, environment: environment)
                let pass = EnvironmentVariableResolver.resolve(request.auth.password, environment: environment)
                parts.append("-u '\(user):\(pass)'")
            }
        case .bearer:
            if !request.auth.token.isEmpty {
                let token = EnvironmentVariableResolver.resolve(request.auth.token, environment: environment)
                parts.append("-H 'Authorization: Bearer \(token)'")
            }
        case .none:
            break
        }
        
        // Body
        switch request.bodyType {
        case .raw:
            if !request.rawBody.isEmpty {
                let body = EnvironmentVariableResolver.resolve(request.rawBody, environment: environment)
                let escapedBody = body.replacingOccurrences(of: "'", with: "'\\''")
                parts.append("-d '\(escapedBody)'")
            }
        case .formUrlEncoded:
            let enabledParams = request.params.filter { $0.isEnabled && !$0.key.isEmpty }
            if !enabledParams.isEmpty {
                let bodyString = enabledParams.map { param -> String in
                    let k = percentEncodeForm(EnvironmentVariableResolver.resolve(param.key, environment: environment))
                    let v = percentEncodeForm(EnvironmentVariableResolver.resolve(param.value, environment: environment))
                    return "\(k)=\(v)"
                }.joined(separator: "&")
                parts.append("-d '\(bodyString)'")
            }
        case .multipart:
            for param in request.params where param.isEnabled && !param.key.isEmpty {
                let k = EnvironmentVariableResolver.resolve(param.key, environment: environment)
                let v = EnvironmentVariableResolver.resolve(param.value, environment: environment)
                let escapedV = v.replacingOccurrences(of: "'", with: "'\\''")
                parts.append("-F '\(k)=\(escapedV)'")
            }
            for file in request.files where file.isEnabled && !file.key.isEmpty && !file.filePath.isEmpty {
                let k = EnvironmentVariableResolver.resolve(file.key, environment: environment)
                parts.append("-F '\(k)=@\(file.filePath)'")
            }
        case .binaryFile:
            if !request.binaryFilePath.isEmpty {
                parts.append("--data-binary '@\(request.binaryFilePath)'")
            }
        case .graphql:
            let resolvedQuery = EnvironmentVariableResolver.resolve(request.graphqlQuery, environment: environment)
            let resolvedVars = EnvironmentVariableResolver.resolve(request.graphqlVariables, environment: environment)
            var payload: [String: Any] = ["query": resolvedQuery]
            if let varsData = resolvedVars.data(using: .utf8),
               let jsonVars = try? JSONSerialization.jsonObject(with: varsData) {
                payload["variables"] = jsonVars
            }
            if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
               let jsonStr = String(data: jsonData, encoding: .utf8) {
                let escaped = jsonStr.replacingOccurrences(of: "'", with: "'\\''")
                parts.append("-d '\(escaped)'")
            }
        }
        
        let resolvedUrl = EnvironmentVariableResolver.resolve(request.url, environment: environment)
        parts.append("'\(resolvedUrl)'")
        
        return parts.joined(separator: " ")
    }

    private static func percentEncodeForm(_ string: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        let encoded = string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
        return encoded.replacingOccurrences(of: " ", with: "%20")
    }
}
