//
//  VariableExtractorTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class VariableExtractorTests: XCTestCase {
    func testVariableExtractionFromJsonAndHeaders() {
        let json = """
        {
          "auth": {
            "accessToken": "secret-session-token-xyz",
            "expiresIn": 3600
          }
        }
        """

        let response = NetworkResponse(
            statusCode: 200,
            statusDescription: "OK",
            headers: [
                KeyValuePair(key: "X-Trace-Id", value: "trace-987654321")
            ],
            bodyData: json.data(using: .utf8)!,
            formattedBody: json
        )

        let rules: [VariableExtractionRule] = [
            VariableExtractionRule(source: .jsonBody, sourceKey: "auth.accessToken", targetEnvironmentVariable: "TOKEN"),
            VariableExtractionRule(source: .jsonBody, sourceKey: "auth.expiresIn", targetEnvironmentVariable: "EXPIRY"),
            VariableExtractionRule(source: .responseHeader, sourceKey: "X-Trace-Id", targetEnvironmentVariable: "TRACE_ID")
        ]

        var envVars: [String: String] = [:]
        let extracted = VariableExtractor.extractVariables(rules: rules, response: response, intoVariables: &envVars)

        XCTAssertEqual(extracted["TOKEN"], "secret-session-token-xyz")
        XCTAssertEqual(extracted["EXPIRY"], "3600")
        XCTAssertEqual(extracted["TRACE_ID"], "trace-987654321")

        XCTAssertEqual(envVars["TOKEN"], "secret-session-token-xyz")
        XCTAssertEqual(envVars["EXPIRY"], "3600")
        XCTAssertEqual(envVars["TRACE_ID"], "trace-987654321")
    }
}
