//
//  TestRunner.swift
//  CocoaRestClientCore
//

import Foundation

public struct TestRunner: Sendable {
    public init() {}

    public static func evaluate(assertions: [TestAssertion], response: NetworkResponse) -> [TestResult] {
        return assertions.compactMap { assertion -> TestResult? in
            guard assertion.isEnabled else { return nil }
            return runSingle(assertion: assertion, response: response)
        }
    }

    private static func runSingle(assertion: TestAssertion, response: NetworkResponse) -> TestResult {
        switch assertion.type {
        case .statusCodeEquals:
            let expectedCode = Int(assertion.expectedValue.trimmingCharacters(in: .whitespaces)) ?? 200
            let passed = response.statusCode == expectedCode
            let msg = passed
                ? "Status code is \(response.statusCode) (expected \(expectedCode))"
                : "Status code is \(response.statusCode) but expected \(expectedCode)"
            return TestResult(assertion: assertion, passed: passed, message: msg)

        case .is2xxSuccess:
            let passed = response.statusCode >= 200 && response.statusCode < 300
            let msg = passed
                ? "Status code \(response.statusCode) is in 2xx success range"
                : "Status code \(response.statusCode) is not in 2xx success range"
            return TestResult(assertion: assertion, passed: passed, message: msg)

        case .responseTimeLessThan:
            let maxMs = Double(assertion.expectedValue.trimmingCharacters(in: .whitespaces)) ?? 1000.0
            let actualMs = response.duration * 1000.0
            let passed = actualMs <= maxMs
            let msg = passed
                ? "Response time \(String(format: "%.1f", actualMs)) ms <= \(String(format: "%.0f", maxMs)) ms"
                : "Response time \(String(format: "%.1f", actualMs)) ms exceeded \(String(format: "%.0f", maxMs)) ms"
            return TestResult(assertion: assertion, passed: passed, message: msg)

        case .bodyContains:
            let needle = assertion.expectedValue
            let passed = response.body.contains(needle)
            let msg = passed
                ? "Body contains string: \"\(needle)\""
                : "Body does not contain string: \"\(needle)\""
            return TestResult(assertion: assertion, passed: passed, message: msg)

        case .headerExists:
            let headerName = assertion.targetKey.trimmingCharacters(in: .whitespaces)
            let passed = response.headers.contains(where: { $0.key.caseInsensitiveCompare(headerName) == .orderedSame })
            let msg = passed
                ? "Header \"\(headerName)\" is present"
                : "Header \"\(headerName)\" is missing from response"
            return TestResult(assertion: assertion, passed: passed, message: msg)

        case .headerEquals:
            let headerName = assertion.targetKey.trimmingCharacters(in: .whitespaces)
            let expectedVal = assertion.expectedValue.trimmingCharacters(in: .whitespaces)
            if let found = response.headers.first(where: { $0.key.caseInsensitiveCompare(headerName) == .orderedSame }) {
                let passed = found.value == expectedVal
                let msg = passed
                    ? "Header \"\(headerName)\" equals \"\(expectedVal)\""
                    : "Header \"\(headerName)\" value \"\(found.value)\" != \"\(expectedVal)\""
                return TestResult(assertion: assertion, passed: passed, message: msg)
            } else {
                return TestResult(assertion: assertion, passed: false, message: "Header \"\(headerName)\" not found")
            }

        case .jsonKeyExists:
            let path = assertion.targetKey.trimmingCharacters(in: .whitespaces)
            let val = resolveJsonPath(path: path, inBody: response.body)
            let passed = val != nil
            let msg = passed
                ? "JSON path \"\(path)\" exists (value: \(val ?? "null"))"
                : "JSON path \"\(path)\" was not found in response"
            return TestResult(assertion: assertion, passed: passed, message: msg)

        case .jsonKeyEquals:
            let path = assertion.targetKey.trimmingCharacters(in: .whitespaces)
            let expectedVal = assertion.expectedValue.trimmingCharacters(in: .whitespaces)
            if let val = resolveJsonPath(path: path, inBody: response.body) {
                let passed = val == expectedVal
                let msg = passed
                    ? "JSON path \"\(path)\" equals \"\(expectedVal)\""
                    : "JSON path \"\(path)\" is \"\(val)\", expected \"\(expectedVal)\""
                return TestResult(assertion: assertion, passed: passed, message: msg)
            } else {
                return TestResult(assertion: assertion, passed: false, message: "JSON path \"\(path)\" was not found")
            }
        }
    }

    public static func resolveJsonPath(path: String, inBody body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else { return nil }

        let cleanPath = path.hasPrefix("$.") ? String(path.dropFirst(2)) : path
        let keys = cleanPath.split(separator: ".").map(String.init)
        guard !keys.isEmpty else { return nil }

        var current: Any = json
        for key in keys {
            if let dict = current as? [String: Any], let next = dict[key] {
                current = next
            } else if let arr = current as? [Any], let idx = Int(key), idx >= 0, idx < arr.count {
                current = arr[idx]
            } else {
                return nil
            }
        }

        if let str = current as? String {
            return str
        } else if let num = current as? NSNumber {
            return num.stringValue
        } else if let boolVal = current as? Bool {
            return boolVal ? "true" : "false"
        } else if let childData = try? JSONSerialization.data(withJSONObject: current, options: []),
                  let childStr = String(data: childData, encoding: .utf8) {
            return childStr
        }
        return nil
    }
}
