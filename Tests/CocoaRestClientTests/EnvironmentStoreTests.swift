//
//  EnvironmentStoreTests.swift
//  CocoaRestClientTests
//

import XCTest
@testable import CocoaRestClientCore

final class EnvironmentStoreTests: XCTestCase {
    func testEnvironmentProfileAsDictionary() {
        let env = EnvironmentProfile(name: "Test", variables: [
            KeyValuePair(key: "host", value: "api.local", isEnabled: true),
            KeyValuePair(key: "disabledVar", value: "ignored", isEnabled: false),
            KeyValuePair(key: "port", value: "8080", isEnabled: true)
        ])
        
        let dict = env.asDictionary()
        XCTAssertEqual(dict["host"], "api.local")
        XCTAssertEqual(dict["port"], "8080")
        XCTAssertNil(dict["disabledVar"])
    }

    func testEnvironmentVariableResolverDoubleBraces() {
        let env = ["apiHost": "example.com", "apiVersion": "v2"]
        let template = "https://{{apiHost}}/api/{{apiVersion}}/users"
        let resolved = EnvironmentVariableResolver.resolve(template, environment: env)
        XCTAssertEqual(resolved, "https://example.com/api/v2/users")
    }

    func testEnvironmentVariableResolverDollarBraces() {
        let env = ["PORT": "3000"]
        let template = "http://localhost:${PORT}/status"
        let resolved = EnvironmentVariableResolver.resolve(template, environment: env)
        XCTAssertEqual(resolved, "http://localhost:3000/status")
    }
}
