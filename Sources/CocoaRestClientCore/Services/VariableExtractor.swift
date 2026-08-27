//
//  VariableExtractor.swift
//  CocoaRestClientCore
//

import Foundation

public struct VariableExtractor: Sendable {
    public init() {}

    public static func extractVariables(
        rules: [VariableExtractionRule],
        response: NetworkResponse,
        intoVariables variables: inout [String: String]
    ) -> [String: String] {
        var extracted: [String: String] = [:]

        for rule in rules where rule.isEnabled {
            let targetVar = rule.targetEnvironmentVariable.trimmingCharacters(in: .whitespaces)
            guard !targetVar.isEmpty else { continue }

            var extractedValue: String?

            switch rule.source {
            case .jsonBody:
                extractedValue = TestRunner.resolveJsonPath(path: rule.sourceKey, inBody: response.body)

            case .responseHeader:
                let headerKey = rule.sourceKey.trimmingCharacters(in: .whitespaces)
                extractedValue = response.headers.first(where: { $0.key.caseInsensitiveCompare(headerKey) == .orderedSame })?.value

            case .regexBody:
                let pattern = rule.sourceKey
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let nsString = response.body as NSString
                    let fullRange = NSRange(location: 0, length: nsString.length)
                    if let match = regex.firstMatch(in: response.body, options: [], range: fullRange) {
                        if match.numberOfRanges > 1 {
                            let groupRange = match.range(at: 1)
                            extractedValue = nsString.substring(with: groupRange)
                        } else {
                            extractedValue = nsString.substring(with: match.range)
                        }
                    }
                }
            }

            if let val = extractedValue {
                variables[targetVar] = val
                extracted[targetVar] = val
            }
        }

        return extracted
    }
}
