//
//  EnvironmentVariableResolver.swift
//  CocoaRestClientCore
//

import Foundation

public struct EnvironmentVariableResolver: Sendable {
    public init() {}

    public static func resolve(_ template: String, environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        guard template.contains("${") else { return template }
        
        var result = template
        let pattern = #"\$\{([^}]+)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return template
        }
        
        let nsString = result as NSString
        let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches.reversed() {
            let fullRange = match.range(at: 0)
            let varNameRange = match.range(at: 1)
            let varName = nsString.substring(with: varNameRange)
            
            if let value = environment[varName] {
                if let swiftRange = Range(fullRange, in: result) {
                    result.replaceSubrange(swiftRange, with: value)
                }
            }
        }
        
        return result
    }
}
