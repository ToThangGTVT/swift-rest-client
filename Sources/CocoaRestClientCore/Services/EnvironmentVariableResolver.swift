//
//  EnvironmentVariableResolver.swift
//  CocoaRestClientCore
//

import Foundation

public struct EnvironmentVariableResolver: Sendable {
    public init() {}

    public static func resolve(_ template: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        var result = template
        
        // 1. Resolve ${VAR}
        if result.contains("${") {
            let pattern = #"\$\{([^}]+)\}"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsString = result as NSString
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches.reversed() {
                    let fullRange = match.range(at: 0)
                    let varName = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                    if let value = environment[varName] {
                        if let swiftRange = Range(fullRange, in: result) {
                            result.replaceSubrange(swiftRange, with: value)
                        }
                    }
                }
            }
        }
        
        // 2. Resolve {{VAR}}
        if result.contains("{{") {
            let pattern = #"\{\{([^}]+)\}\}"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsString = result as NSString
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
                for match in matches.reversed() {
                    let fullRange = match.range(at: 0)
                    let varName = nsString.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                    if let value = environment[varName] {
                        if let swiftRange = Range(fullRange, in: result) {
                            result.replaceSubrange(swiftRange, with: value)
                        }
                    }
                }
            }
        }

        return result
    }
}
