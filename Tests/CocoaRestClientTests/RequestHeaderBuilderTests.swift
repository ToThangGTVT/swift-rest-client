//
//  RequestHeaderBuilderTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class RequestHeaderBuilderTests: XCTestCase {
    private let env = ["token": "s3cr3t", "keyName": "X-Tenant"]

    func testExplicitHeadersResolveVariablesAndSkipDisabledRows() {
        let built = RequestHeaderBuilder.build(
            headers: [
                KeyValuePair(key: "{{keyName}}", value: "acme", isEnabled: true),
                KeyValuePair(key: "X-Off", value: "no", isEnabled: false),
                KeyValuePair(key: "", value: "nameless", isEnabled: true)
            ],
            environment: env,
            includeCookies: false
        )

        XCTAssertEqual(built["X-Tenant"], "acme")
        XCTAssertNil(built["X-Off"])
        XCTAssertEqual(built.count, 1)
    }

    func testBearerTokenResolvesEnvironmentVariables() {
        let built = RequestHeaderBuilder.build(
            headers: [],
            auth: Authentication(type: .bearer, token: "{{token}}"),
            environment: env,
            includeCookies: false
        )

        XCTAssertEqual(built["Authorization"], "Bearer s3cr3t")
    }

    func testAuthOverridesAHandWrittenAuthorizationHeader() {
        let built = RequestHeaderBuilder.build(
            headers: [KeyValuePair(key: "Authorization", value: "Bearer stale", isEnabled: true)],
            auth: Authentication(type: .basic, username: "u", password: "p"),
            includeCookies: false
        )

        XCTAssertEqual(built["Authorization"], "Basic \("u:p".data(using: .utf8)!.base64EncodedString())")
    }

    func testBasicAuthIsSkippedWhenNotPreemptive() {
        let built = RequestHeaderBuilder.build(
            headers: [],
            auth: Authentication(type: .basic, username: "u", password: "p", isPreemptive: false),
            includeCookies: false
        )

        XCTAssertNil(built["Authorization"])
    }

    func testApiKeyInQueryDoesNotBecomeAHeader() {
        let header = RequestHeaderBuilder.build(
            headers: [],
            auth: Authentication(type: .apiKey, apiKeyName: "X-Key", apiKeyValue: "v", apiKeyLocation: .header),
            includeCookies: false
        )
        XCTAssertEqual(header["X-Key"], "v")

        let query = RequestHeaderBuilder.build(
            headers: [],
            auth: Authentication(type: .apiKey, apiKeyName: "X-Key", apiKeyValue: "v", apiKeyLocation: .query),
            includeCookies: false
        )
        XCTAssertTrue(query.isEmpty)
    }

    func testNoAuthTypeAddsNothing() {
        let built = RequestHeaderBuilder.build(headers: [], auth: Authentication(), includeCookies: false)
        XCTAssertTrue(built.isEmpty)
    }
}
