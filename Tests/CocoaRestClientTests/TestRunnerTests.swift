//
//  TestRunnerTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class TestRunnerTests: XCTestCase {
    func testTestAssertionsEvaluation() {
        let json = """
        {
          "status": "ok",
          "code": 200,
          "data": {
            "token": "sample-jwt-token-999",
            "userId": 42
          }
        }
        """

        let response = NetworkResponse(
            statusCode: 200,
            statusDescription: "OK",
            headers: [
                KeyValuePair(key: "Content-Type", value: "application/json"),
                KeyValuePair(key: "X-Server-Id", value: "srv-01")
            ],
            bodyData: json.data(using: .utf8)!,
            formattedBody: json,
            latencyMs: 150.0,
            duration: 0.15
        )

        let assertions: [TestAssertion] = [
            TestAssertion(type: .statusCodeEquals, expectedValue: "200"),
            TestAssertion(type: .is2xxSuccess),
            TestAssertion(type: .responseTimeLessThan, expectedValue: "500"),
            TestAssertion(type: .bodyContains, expectedValue: "sample-jwt-token-999"),
            TestAssertion(type: .headerExists, targetKey: "X-Server-Id"),
            TestAssertion(type: .headerEquals, targetKey: "X-Server-Id", expectedValue: "srv-01"),
            TestAssertion(type: .jsonKeyExists, targetKey: "data.token"),
            TestAssertion(type: .jsonKeyEquals, targetKey: "data.userId", expectedValue: "42"),
            TestAssertion(type: .statusCodeEquals, expectedValue: "404") // Expected to fail
        ]

        let results = TestRunner.evaluate(assertions: assertions, response: response)
        XCTAssertEqual(results.count, 9)

        let passed = results.filter { $0.passed }
        let failed = results.filter { !$0.passed }

        XCTAssertEqual(passed.count, 8)
        XCTAssertEqual(failed.count, 1)
        XCTAssertEqual(failed.first?.assertion.expectedValue, "404")
    }
}
