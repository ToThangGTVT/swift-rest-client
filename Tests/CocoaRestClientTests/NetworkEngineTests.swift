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
