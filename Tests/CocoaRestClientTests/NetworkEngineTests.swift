//
//  NetworkEngineTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class NetworkEngineTests: XCTestCase {
    func testNetworkOptionsDefaults() {
        let options = NetworkOptions()
        XCTAssertEqual(options.timeoutSeconds, 30)
        XCTAssertTrue(options.followRedirects)
        XCTAssertFalse(options.applyHttpMethodOnRedirect)
        XCTAssertTrue(options.allowSelfSignedCerts)
        XCTAssertFalse(options.disableCookies)
    }

    func testUrlVariablesResolveBeforeSchemeFallback() {
        let env = ["baseUrl": "https://httpbin.org", "host": "example.com"]

        // The scheme lives inside the variable -- it must not be prefixed again.
        var request = RestRequest(url: "{{baseUrl}}/get")
        XCTAssertEqual(
            NetworkEngine.requestUrlString(for: request, environment: env),
            "https://httpbin.org/get"
        )

        request = RestRequest(url: "${baseUrl}/get")
        XCTAssertEqual(
            NetworkEngine.requestUrlString(for: request, environment: env),
            "https://httpbin.org/get"
        )

        // A variable that expands to a bare host still gets the fallback scheme.
        request = RestRequest(url: "{{host}}/get")
        XCTAssertEqual(
            NetworkEngine.requestUrlString(for: request, environment: env),
            "http://example.com/get"
        )

        // Unresolvable variables keep the old behaviour.
        request = RestRequest(url: "api.example.com/get")
        XCTAssertEqual(
            NetworkEngine.requestUrlString(for: request, environment: env),
            "http://api.example.com/get"
        )
    }

    func testNetworkResponseInitialization() {
        let response = NetworkResponse(
            statusCode: 200,
            statusDescription: "OK",
            headers: [KeyValuePair(key: "Content-Type", value: "application/json", isEnabled: true)],
            bodyData: "{\"status\":\"ok\"}".data(using: .utf8)!,
            formattedBody: "{\n  \"status\": \"ok\"\n}",
            latencyMs: 45.2
        )
        
        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers.count, 1)
        XCTAssertEqual(response.latencyMs, 45.2)
    }
}
